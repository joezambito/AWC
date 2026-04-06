import Foundation
import Network
import OSLog

// MARK: - Events

enum WealthIBKRBridgeEvent: Equatable {
    case connecting
    case connected
    case disconnected(String)
    case failed(String)
    case quote(WealthBrokerQuote)
}

// MARK: - Supporting Types

struct WealthBrokerQuote: Equatable {
    let symbol: String
    let bid:    Double
    let ask:    Double
    let last:   Double
    let volume: Int
}

struct WealthIBKRContract: Equatable {
    let symbol:   String
    let secType:  String
    let exchange: String
    let currency: String
    let conId:    Int?
}

// MARK: - WealthIBKRBridge

@MainActor
final class WealthIBKRBridge {

    static let shared = WealthIBKRBridge()

    // MARK: - Network queue
    //
    // NWConnection callbacks are delivered on this private serial queue,
    // not on .main. Every callback hops to @MainActor via
    // Task { @MainActor in ... } so bridge logic runs on the main actor.
    private static let ibkrNetworkQueue = DispatchQueue(
        label: "com.awc.ibkr-bridge",
        qos: .userInitiated
    )

    typealias EventHandler = @MainActor (WealthIBKRBridgeEvent) -> Void

    struct Subscription {
        let contract:  WealthIBKRContract
        let requestID: Int
    }

    struct ContractValidationRequest {
        let candidate: WealthIBKRContract
        var matches:   [WealthIBKRContract] = []
        var continuation: CheckedContinuation<[WealthIBKRContract], Never>?
    }

    // MARK: - State

    private(set) var apiReady = false
    private(set) var serverVersion: Int = 0
    private(set) var connectionTime: String = ""

    let negotiatedClientVersionRange = "v100..176"

    var clientID: Int

    private var connection: NWConnection?
    private var eventHandlers: [EventHandler] = []
    private(set) var subscriptions: [Int: Subscription] = [:]
    private var nextRequestID = 1
    var receiveBuffer = Data()

    // MARK: - Startup connection gate
    //
    // IBKR must not connect until the universe scan has completed.
    // Callers (WealthCore.swift) may invoke connect() at any time; if the
    // universe is still loading the request is stored and fired automatically
    // once permitConnectionAfterStartup() is called by the startup controller.

    private(set) var startupConnectionPermitted: Bool = false
    private var pendingConnect: (host: String, port: UInt16)?

    // MARK: - Init

    private init() {
        self.clientID = AWCSecretConfig.shared.ibkrClientID
    }

    // MARK: - Startup gate

    /// Called by WealthEngineStartupController after the universe scan
    /// finishes. Fires any deferred connect() request immediately.
    func permitConnectionAfterStartup() {
        guard !startupConnectionPermitted else { return }
        startupConnectionPermitted = true

        if let pending = pendingConnect {
            pendingConnect = nil
            connect(host: pending.host, port: pending.port)
        }
    }

    // MARK: - Event Subscription

    func addEventHandler(_ handler: @escaping EventHandler) {
        eventHandlers.append(handler)
    }

    func emit(_ event: WealthIBKRBridgeEvent) {
        switch event {
        case .connecting:
            WealthStartupLagTracer.shared.trace("IBKRBridge.emit – .connecting (TCP dial started)")
        case .connected:
            WealthStartupLagTracer.shared.trace("IBKRBridge.emit – .connected (handshake complete)")
        default:
            break
        }
        for handler in eventHandlers { handler(event) }
    }

    // MARK: - Connection

    func connect(host: String, port: UInt16) {
        guard !host.trimmingCharacters(in: .whitespaces).isEmpty else {
            emit(.failed("IBKRBridge: connect() called with empty host — check TWS host configuration."))
            return
        }
        guard port > 0 else {
            emit(.failed("IBKRBridge: connect() called with port 0 — check TWS port configuration."))
            return
        }

        guard startupConnectionPermitted else {
            pendingConnect = (host, port)
            WealthStartupLagTracer.shared.trace("IBKRBridge.connect – deferred (universe not yet loaded) host=\(host):\(port)")
            return
        }

        WealthStartupLagTracer.shared.trace("IBKRBridge.connect – called host=\(host):\(port)")

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port)
        )
        let conn = NWConnection(to: endpoint, using: .tcp)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionState(state)
            }
        }

        conn.start(queue: Self.ibkrNetworkQueue)
        emit(.connecting)
        startReceiving()
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        apiReady = false
        emit(.disconnected("Manual disconnect"))
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            sendGreeting()
        case .failed(let error):
            emit(.failed(error.localizedDescription))
        case .cancelled:
            emit(.disconnected("Connection cancelled"))
        default:
            break
        }
    }

    // MARK: - Receive Loop

    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self = self else { return }
                if let data = data, !data.isEmpty {
                    self.receiveBuffer.append(data)
                    self.logReceivedBytes(data, label: self.apiReady ? "api" : "handshake")
                    self.processReceiveBuffer()
                }
                if let error = error {
                    let event = WealthIBKRBridgeEvent.failed(error.localizedDescription)
                    self.diagnoseRejection(event: event)
                    self.emit(event)
                    return
                }
                if isComplete {
                    self.emit(.disconnected("Connection closed by server"))
                    return
                }
                self.startReceiving()
            }
        }
    }

    func processReceiveBuffer() {
        if !apiReady {
            handleHandshakeBuffer()
        } else {
            while receiveBuffer.count >= 4 {
                let length = Int(receiveBuffer[0]) << 24
                           | Int(receiveBuffer[1]) << 16
                           | Int(receiveBuffer[2]) << 8
                           | Int(receiveBuffer[3])
                guard receiveBuffer.count >= 4 + length else { break }
                let messageData = receiveBuffer.subdata(in: 4..<(4 + length))
                receiveBuffer.removeFirst(4 + length)
                handleApiMessage(data: messageData)
            }
        }
    }

    private func handleHandshakeBuffer() {
        guard let firstNull = receiveBuffer.firstIndex(of: 0) else { return }
        let versionString = String(bytes: receiveBuffer.prefix(firstNull), encoding: .utf8) ?? ""
        let rest = receiveBuffer.dropFirst(firstNull + 1)
        guard let secondNull = rest.firstIndex(of: 0) else { return }
        let timeString = String(bytes: rest.prefix(secondNull - rest.startIndex), encoding: .utf8) ?? ""

        receiveBuffer.removeFirst(secondNull - receiveBuffer.startIndex + 1)

        validateField(versionString, name: "serverVersion")
        validateField(timeString, name: "connectionTime")

        if let version = Int(versionString), validateServerVersion(version) {
            serverVersion = version
            connectionTime = timeString
            logHandshakeState("handshakeComplete", detail: "serverVersion=\(version) time=\(timeString)")
            sendStartAPI()
            apiReady = true
            emit(.connected)
        } else {
            logHandshakeState("handshakeFailed", detail: "Could not parse serverVersion from '\(versionString)'")
            emit(.failed("Invalid serverVersion in handshake: '\(versionString)'"))
        }
    }

    private func handleApiMessage(data: Data) {}

    // MARK: - Low-Level Send

    func sendRaw(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed({ [weak self] error in
            if let error = error {
                Task { @MainActor in
                    self?.emit(.failed("Send error: \(error.localizedDescription)"))
                }
            }
        }))
    }

    func prefixed(_ data: Data) -> Data {
        var length = UInt32(data.count).bigEndian
        return Data(bytes: &length, count: 4) + data
    }

    func send(_ fields: [String]) {
        let body = fields.joined(separator: "\0").appending("\0")
        sendRaw(prefixed(Data(body.utf8)))
    }

    func nextReqID() -> Int {
        defer { nextRequestID += 1 }
        return nextRequestID
    }
}
