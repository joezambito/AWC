import Foundation
import Network
import OSLog

enum WealthIBKRBridgeEvent: Equatable {
    case connecting
    case connected
    case disconnected(String)
    case failed(String)
    case quote(WealthBrokerQuote)
}

@MainActor
final class WealthIBKRBridge {
    static let shared = WealthIBKRBridge()

    typealias EventHandler = @MainActor (WealthIBKRBridgeEvent) -> Void

    struct Subscription {
        let contract: WealthIBKRContract
        let requestID: Int
    }

    struct ContractValidationRequest {
        let candidate: WealthIBKRContract
        var matches: [WealthIBKRContract] = []
        var continuation: CheckedContinuation<WealthIBKRContract?, Never>? = nil
        var timeoutTask: Task<Void, Never>? = nil
    }

    struct PartialQuote {
        let currency: String
        var last: Double?
        var close: Double?
        var bid: Double?
        var ask: Double?
        var lastSize: Int?
        var bidSize: Int?
        var askSize: Int?
        var timestamp = Date()
        var isDelayed = false
    }

    let queue = DispatchQueue(label: "com.zulugames.awc.ibkrbridge")
    let logger = Logger(subsystem: "com.zulugames.awc", category: "IBKRBridge")
    var connection: NWConnection?
    var handler: EventHandler?
    var silentCancel = false
    var cancelReason = "Disconnected from TWS."
    var receiveBuffer = Data()
    var hasValidRequestID = false
    var hasManagedAccounts = false
    var apiReady = false
    var clientID = 77
    var nextRequestID = 90_000
    var delayedQuotesEnabled = true
    var subscriptions: [WealthBrokerQuoteKey: Subscription] = [:]
    var requestIDToKey: [Int: WealthBrokerQuoteKey] = [:]
    var requestIDToContract: [Int: WealthIBKRContract] = [:]
    var partialQuotes: [Int: PartialQuote] = [:]
    var snapshotRequestIDs: Set<Int> = []
    var snapshotCleanupTasks: [Int: Task<Void, Never>] = [:]
    var desiredHost = "127.0.0.1"
    var desiredPort = 7497
    var shouldMaintainConnection = false
    var reconnectTask: Task<Void, Never>?
    var reconnectAttempt = 0
    var fallbackToDelayedSent = false
    var contractValidationRequests: [Int: ContractValidationRequest] = [:]
    var validatingKeys: Set<WealthBrokerQuoteKey> = []

    private init() {}

    func connect(host: String, port: Int, handler: @escaping EventHandler) {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            emit(.failed("Broker host is empty."))
            return
        }

        guard (1...65535).contains(port), let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            emit(.failed("Broker port is invalid."))
            return
        }

        disconnect(silent: true, maintainConnection: true)
        self.handler = handler
        desiredHost = trimmedHost
        desiredPort = port
        shouldMaintainConnection = true
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0
        clientID = nextClientID()
        logger.log("Connecting to TWS at \(trimmedHost, privacy: .public):\(port, privacy: .public) with clientId \(self.clientID, privacy: .public)")
        WealthLiveMarketDataStore.shared.noteConnectionAttempt(
            host: trimmedHost,
            port: port,
            clientID: clientID
        )
        emit(.connecting)

        let connection = NWConnection(host: .init(trimmedHost), port: endpointPort, using: .tcp)
        self.connection = connection
        resetSessionState()

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let bridge = self else { return }
            Task { @MainActor in
                guard let trackedConnection = connection else { return }
                bridge.handle(state, from: trackedConnection)
            }
        }

        connection.start(queue: queue)
    }

    func disconnect() {
        disconnect(silent: false, maintainConnection: false)
    }

    func subscribe(to contracts: [WealthIBKRContract], delayedQuotes: Bool) {
        delayedQuotesEnabled = delayedQuotes
        guard connection != nil, apiReady else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let validatedContracts = await self.validatedContracts(from: contracts)
            guard self.connection != nil, self.apiReady else { return }

            self.sendMarketDataType(self.fallbackToDelayedSent ? 3 : 1)

            for contract in validatedContracts where self.subscriptions[contract.key] == nil {
                let requestID = self.nextRequestID
                self.nextRequestID += 1
                self.subscriptions[contract.key] = Subscription(contract: contract, requestID: requestID)
                self.requestIDToKey[requestID] = contract.key
                self.requestIDToContract[requestID] = contract
                self.partialQuotes[requestID] = PartialQuote(currency: contract.currency)
                self.sendMarketDataRequest(contract, requestID: requestID)
            }
        }
    }

    func requestSnapshots(for contracts: [WealthIBKRContract], delayedQuotes: Bool) {
        delayedQuotesEnabled = delayedQuotes
        guard connection != nil, apiReady else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let validatedContracts = await self.validatedContracts(from: contracts)
            guard self.connection != nil, self.apiReady else { return }

            self.sendMarketDataType(self.fallbackToDelayedSent ? 3 : 1)

            for contract in validatedContracts {
                let requestID = self.nextRequestID
                self.nextRequestID += 1
                self.requestIDToKey[requestID] = contract.key
                self.requestIDToContract[requestID] = contract
                self.partialQuotes[requestID] = PartialQuote(currency: contract.currency)
                self.snapshotRequestIDs.insert(requestID)
                self.snapshotCleanupTasks[requestID]?.cancel()
                self.snapshotCleanupTasks[requestID] = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    self?.cleanupSnapshotRequest(requestID)
                }
                self.sendMarketDataRequest(contract.snapshotContract(), requestID: requestID)
            }
        }
    }

    func emit(_ event: WealthIBKRBridgeEvent) {
        handler?(event)
    }

    func cleanupSnapshotRequest(_ requestID: Int) {
        guard snapshotRequestIDs.contains(requestID) else { return }
        snapshotRequestIDs.remove(requestID)
        snapshotCleanupTasks[requestID]?.cancel()
        snapshotCleanupTasks[requestID] = nil
        requestIDToKey[requestID] = nil
        requestIDToContract[requestID] = nil
        partialQuotes[requestID] = nil
    }

    private func resetSessionState() {
        receiveBuffer = Data()
        hasValidRequestID = false
        hasManagedAccounts = false
        apiReady = false
        fallbackToDelayedSent = false
        contractValidationRequests.values.forEach { $0.timeoutTask?.cancel() }
        contractValidationRequests.removeAll()
        validatingKeys.removeAll()
    }

    private func disconnect(silent: Bool, maintainConnection: Bool) {
        shouldMaintainConnection = maintainConnection
        reconnectTask?.cancel()
        reconnectTask = nil
        guard let connection else {
            if !silent {
                emit(.disconnected("Disconnected from TWS."))
            }
            return
        }

        silentCancel = silent
        cancelReason = "Disconnected from TWS."
        self.connection = nil
        connection.cancel()
    }

    func scheduleReconnect(reason: String) {
        guard shouldMaintainConnection else { return }
        reconnectTask?.cancel()
        reconnectAttempt += 1
        let attempt = reconnectAttempt
        let delay = min(UInt64(max(2, attempt * 2)), 15)
        logger.log("Scheduling TWS reconnect attempt \(attempt, privacy: .public) in \(delay, privacy: .public)s: \(reason, privacy: .public)")
        WealthLiveMarketDataStore.shared.noteFailed("Reconnect in \(delay)s: \(reason)")
        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            guard let self, self.shouldMaintainConnection else { return }
            guard let handler = self.handler else { return }
            self.connect(host: self.desiredHost, port: self.desiredPort, handler: handler)
        }
    }

    func useDelayedFallback(reason: String) {
        guard !fallbackToDelayedSent else { return }
        fallbackToDelayedSent = true
        delayedQuotesEnabled = true
        logger.log("Switching to delayed market data: \(reason, privacy: .public)")
        WealthLiveMarketDataStore.shared.noteMarketDataType(3)
        sendMarketDataType(3)
        resubscribeAllContracts()
    }

    private func nextClientID() -> Int {
        let defaults = UserDefaults.standard
        let storageKey = "awc_ibkr_client_id_seed"
        let seed = defaults.integer(forKey: storageKey)
        let next = (seed >= 9_000 ? 1_000 : max(seed + 1, 1_000))
        defaults.set(next, forKey: storageKey)
        return next
    }
}
