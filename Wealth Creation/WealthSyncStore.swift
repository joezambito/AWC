import SwiftUI
import Combine

@MainActor
final class WealthSyncStore: ObservableObject {
    static let shared = WealthSyncStore()

    enum ScanBrokerAccessResult {
        case reusedLiveConnection
        case waitingForHandshake
        case startedBurst
        case unavailable
    }

    private struct BrokerEndpoint {
        let host: String
        let port: Int
        let modeLabel: String
        let accountID: String
    }

    private enum StorageKey {
        static let macBridgeEnabled = "awc_sync_mac_bridge_enabled"
        static let cloudSyncEnabled = "awc_sync_cloud_enabled"
        static let brokerHost = "awc_sync_broker_host"
        static let brokerPort = "awc_sync_broker_port"
        static let liveMode = "awc_sync_live_mode"
    }

    @Published var macBridgeEnabled: Bool {
        didSet { defaults.set(macBridgeEnabled, forKey: StorageKey.macBridgeEnabled) }
    }

    @Published var cloudSyncEnabled: Bool {
        didSet { defaults.set(cloudSyncEnabled, forKey: StorageKey.cloudSyncEnabled) }
    }

    @Published var brokerHost: String {
        didSet { defaults.set(brokerHost, forKey: StorageKey.brokerHost) }
    }

    @Published var brokerPort: Int {
        didSet { defaults.set(brokerPort, forKey: StorageKey.brokerPort) }
    }

    @Published var liveMode: Bool {
        didSet { defaults.set(liveMode, forKey: StorageKey.liveMode) }
    }

    @Published var syncStatus: String {
        didSet {
            if oldValue != syncStatus {
                syncStatusUpdatedAt = .now
            }
        }
    }
    @Published var syncStatusUpdatedAt: Date
    @Published var lastPhoneSync: Date?
    @Published var lastMacSync: Date?
    @Published var syncLog: [SyncSnapshot]

    private let defaults = UserDefaults.standard
    private var scanBurstShutdownTask: Task<Void, Never>?
    private var scanBurstCompletion: CheckedContinuation<Void, Never>?
    private var startupConnectTask: Task<Void, Never>?

    private var shouldPreferPersistentBrokerSession: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }

    private var allowsDirectBrokerAccess: Bool {
        true
    }

    private init() {
        macBridgeEnabled = defaults.object(forKey: StorageKey.macBridgeEnabled) as? Bool ?? true
        cloudSyncEnabled = defaults.object(forKey: StorageKey.cloudSyncEnabled) as? Bool ?? true
        brokerHost = defaults.string(forKey: StorageKey.brokerHost) ?? "127.0.0.1"
        brokerPort = defaults.object(forKey: StorageKey.brokerPort) as? Int ?? 7497
        liveMode = defaults.object(forKey: StorageKey.liveMode) as? Bool ?? false
        syncStatus = "TWS OFFLINE"
        syncStatusUpdatedAt = .now
        lastPhoneSync = .now.addingTimeInterval(-18)
        lastMacSync = .now.addingTimeInterval(-63)
        syncLog = [
            SyncSnapshot(title: "Phone Push", detail: "Phone state pushed into the AWC core.", timestamp: .now.addingTimeInterval(-140)),
            SyncSnapshot(title: "Mac Pull", detail: "Mac bridge refreshed broker and scan state.", timestamp: .now.addingTimeInterval(-320))
        ]

        startupConnectTask = Task { @MainActor [weak self] in
            await Task.yield()
            self?.autoStartBrokerIfNeeded()
        }
    }

    var isTWSConnectedForQuotes: Bool {
        if WealthLiveMarketDataStore.shared.twsConnected { return true }
        return syncStatus == "TWS PAPER" || syncStatus == "TWS LIVE"
    }

    private var resolvedBrokerEndpoint: BrokerEndpoint? {
        let accountID = WealthBrokerStore.shared.ibkrAccountID.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = brokerHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return nil }

        let defaultPort = liveMode ? 7496 : 7497
        let resolvedPort = (1...65535).contains(brokerPort) ? brokerPort : defaultPort

        return BrokerEndpoint(
            host: host,
            port: resolvedPort,
            modeLabel: liveMode ? "live" : "paper",
            accountID: accountID
        )
    }

    func autoStartBrokerIfNeeded() {
        guard allowsDirectBrokerAccess else { return }
        guard WealthBrokerStore.shared.selectedBroker.name == "IBKR" else { return }
        guard resolvedBrokerEndpoint != nil else { return }

        if WealthIBKRBridge.shared.canReuseForQuotes {
            syncStatus = liveMode ? "TWS LIVE" : "TWS PAPER"
            return
        }

        if WealthIBKRBridge.shared.hasOpenConnection {
            syncStatus = "CONNECTING"
            return
        }

        connectBrokerAPI()
    }

    func syncFromPhone() {
        lastPhoneSync = .now
        appendLog(title: "Phone Push", detail: "Phone state pushed into shared core.")
        WealthEventLogStore.shared.record(title: "Phone Sync", detail: "Phone state pushed into shared core.", category: "sync", tintName: "blue")
        WealthCloudSyncCoordinator.shared.syncFromCurrentDevice()
    }

    func syncFromMac() {
        lastMacSync = .now
        appendLog(title: "Mac Pull", detail: "Mac bridge updated broker and engine state.")
        WealthEventLogStore.shared.record(title: "Mac Sync", detail: "Mac bridge updated broker and engine state.", category: "sync", tintName: "blue")
        Task { @MainActor in
            await WealthCloudSyncCoordinator.shared.syncToCurrentDevice()
        }
    }

    func syncEverything() {
        lastPhoneSync = .now
        lastMacSync = .now
        appendLog(title: "Full Sync", detail: "Phone, Mac, broker, and core state aligned.")
        WealthEventLogStore.shared.record(title: "Full Sync", detail: "Phone, Mac, broker, and core state aligned.", category: "sync", tintName: "blue")
        Task { @MainActor in
            await WealthCloudSyncCoordinator.shared.syncRoundTrip()
        }
    }

    func connectBrokerAPI() {
        guard allowsDirectBrokerAccess else {
            syncStatus = "MAC BRIDGE REQUIRED"
            appendLog(
                title: "TWS Disabled On Phone",
                detail: "Phone does not open direct TWS sessions. Use the Mac-approved broker session instead."
            )
            return
        }
        guard let endpoint = resolvedBrokerEndpoint else {
            syncStatus = "TWS FAILED"
            WealthBrokerStore.shared.recordBrokerFailure("Broker host is empty.")
            return
        }
        scanBurstShutdownTask?.cancel()
        scanBurstShutdownTask = nil

        syncStatus = "CONNECTING"
        appendLog(
            title: "TWS Probe",
            detail: "Trying \(endpoint.modeLabel) TWS at \(endpoint.host):\(endpoint.port) for \(endpoint.accountID.isEmpty ? "NO ACCOUNT" : endpoint.accountID)."
        )

        connectToBroker(endpoint: endpoint, maintainConnection: true, scanBurst: false)
    }

    func disconnectBrokerAPI() {
        scanBurstShutdownTask?.cancel()
        scanBurstShutdownTask = nil
        WealthIBKRBridge.shared.disconnect()
        WealthBrokerQuoteStore.shared.clear()
        syncStatus = "TWS OFFLINE"
        WealthEventLogStore.shared.record(title: "TWS Disconnected", detail: "Broker link manually disconnected.", category: "broker", tintName: "orange")
    }

    @discardableResult
    func beginScanBrokerBurst(
        reason: String = "scan burst",
        blueprints: [OpportunityBlueprint] = []
    ) async -> Bool {
        guard allowsDirectBrokerAccess else { return false }
        scanBurstShutdownTask?.cancel()
        scanBurstShutdownTask = nil

        guard let endpoint = resolvedBrokerEndpoint else { return false }
        guard WealthBrokerStore.shared.selectedBroker.name == "IBKR" else { return false }

        if WealthLiveMarketDataStore.shared.twsConnected || WealthIBKRBridge.shared.scanBurstActive {
            if !blueprints.isEmpty {
                WealthBrokerQuoteStore.shared.prepareSubscriptions(for: blueprints)
            }
            return false
        }

        if WealthIBKRBridge.shared.hasOpenConnection {
            if !blueprints.isEmpty {
                WealthBrokerQuoteStore.shared.prepareSubscriptions(for: blueprints)
            }
            return false
        }

        syncStatus = "CONNECTING"
        appendLog(
            title: "TWS Burst",
            detail: "Starting \(reason) at \(endpoint.host):\(endpoint.port)."
        )
        WealthEventLogStore.shared.record(
            title: "IBKR Scan Start",
            detail: "Started \(reason) for \(blueprints.count) cards at \(endpoint.host):\(endpoint.port).",
            category: "scan",
            tintName: "blue"
        )

        let didConnect = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            var resumed = false

            func finish(_ value: Bool) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: value)
            }

            self.connectToBroker(
                endpoint: endpoint,
                maintainConnection: false,
                scanBurst: true
            ) { event in
                switch event {
                case .connected:
                    finish(true)
                case .failed, .disconnected:
                    finish(false)
                case .connecting, .quote:
                    break
                }
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                finish(false)
            }
        }

        guard didConnect else { return false }

        if !blueprints.isEmpty {
            WealthBrokerQuoteStore.shared.prepareSubscriptions(for: blueprints)
            appendLog(
                title: "TWS Warmup",
                detail: "Requested quotes for \(blueprints.count) scan candidates during \(reason)."
            )
            WealthEventLogStore.shared.record(
                title: "IBKR Scan Quotes",
                detail: "Requested broker quotes for \(blueprints.count) cards during \(reason).",
                category: "scan",
                tintName: "cyan"
            )
        }

        return true
    }

    func ensureScanBrokerAccess(
        reason: String = "scan burst",
        blueprints: [OpportunityBlueprint] = []
    ) async -> ScanBrokerAccessResult {
        guard allowsDirectBrokerAccess else { return .unavailable }
        guard WealthBrokerStore.shared.selectedBroker.name == "IBKR" else { return .unavailable }

        if WealthIBKRBridge.shared.scanBurstActive {
            if !blueprints.isEmpty {
                WealthBrokerQuoteStore.shared.prepareSubscriptions(for: blueprints)
            }
            return .reusedLiveConnection
        }

        if shouldPreferPersistentBrokerSession, WealthIBKRBridge.shared.canReuseForQuotes {
            if !blueprints.isEmpty {
                WealthBrokerQuoteStore.shared.prepareSubscriptions(for: blueprints)
            }
            return .reusedLiveConnection
        }

        if shouldPreferPersistentBrokerSession, WealthIBKRBridge.shared.hasOpenConnection {
            if !blueprints.isEmpty {
                WealthBrokerQuoteStore.shared.prepareSubscriptions(for: blueprints)
            }
            return .waitingForHandshake
        }

        let burstStarted = await beginScanBrokerBurst(reason: reason, blueprints: blueprints)
        return burstStarted ? .startedBurst : .unavailable
    }

    func scheduleScanBrokerBurstStop(after delayNanoseconds: UInt64 = 8_000_000_000) {
        scanBurstShutdownTask?.cancel()
        scanBurstShutdownTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard let self else { return }
            guard WealthIBKRBridge.shared.scanBurstActive else { return }
            WealthIBKRBridge.shared.stopScanBurst()
            self.syncStatus = "TWS OFFLINE"
            self.finishScanBurstCompletion()
        }
    }

    func runBlockingScanBrokerBurst(
        reason: String = "scan burst",
        blueprints: [OpportunityBlueprint] = [],
        durationNanoseconds: UInt64 = 8_000_000_000
    ) async {
        let burstStarted = await beginScanBrokerBurst(reason: reason, blueprints: blueprints)
        guard burstStarted else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            scanBurstCompletion = continuation
            scheduleScanBrokerBurstStop(after: durationNanoseconds)
        }
    }

    private func handleBrokerEvent(
        _ event: WealthIBKRBridgeEvent,
        host: String,
        port: Int,
        modeLabel: String,
        accountID: String
    ) {
        switch event {
        case .connecting:
            syncStatus = "CONNECTING"

        case .connected:
            syncStatus = liveMode ? "TWS LIVE" : "TWS PAPER"
            WealthBrokerStore.shared.clearBrokerFailureState()
            lastMacSync = .now
            appendLog(
                title: "TWS Connected",
                detail: "Connected to \(host):\(port) for \(modeLabel) mode using \(accountID.isEmpty ? "NO ACCOUNT" : accountID)."
            )
            WealthEventLogStore.shared.record(title: "TWS Connected", detail: "Broker feed connected in \(modeLabel) mode.", category: "broker", tintName: "green")

        case .disconnected(let detail):
            syncStatus = "TWS OFFLINE"
            finishScanBurstCompletion()
            appendLog(title: "TWS Closed", detail: detail)
            WealthEventLogStore.shared.record(title: "TWS Offline", detail: detail, category: "broker", tintName: "orange")

        case .failed(let detail):
            syncStatus = "TWS FAILED"
            WealthBrokerStore.shared.recordBrokerFailure(detail)
            finishScanBurstCompletion()
            appendLog(title: "TWS Failed", detail: detail)
            WealthEventLogStore.shared.record(title: "TWS Failed", detail: detail, category: "broker", tintName: "red")

        case .quote(let quote):
            WealthBrokerQuoteStore.shared.ingest(quote)
        }
    }

    private func appendLog(title: String, detail: String) {
        syncLog.insert(SyncSnapshot(title: title, detail: detail, timestamp: .now), at: 0)
        syncLog = Array(syncLog.prefix(8))
    }

    private func connectToBroker(
        endpoint: BrokerEndpoint,
        maintainConnection: Bool,
        scanBurst: Bool,
        attemptedLoopbackFallback: Bool = false,
        observer: ((WealthIBKRBridgeEvent) -> Void)? = nil
    ) {
        WealthIBKRBridge.shared.connect(
            host: endpoint.host,
            port: endpoint.port,
            maintainConnection: maintainConnection,
            scanBurst: scanBurst
        ) { [weak self] event in
            guard let self else {
                observer?(event)
                return
            }

            if self.shouldRetryViaLoopback(after: event, endpoint: endpoint, attemptedLoopbackFallback: attemptedLoopbackFallback) {
                let fallbackEndpoint = BrokerEndpoint(
                    host: "127.0.0.1",
                    port: endpoint.port,
                    modeLabel: endpoint.modeLabel,
                    accountID: endpoint.accountID
                )
                self.syncStatus = "CONNECTING"
                self.appendLog(
                    title: "TWS Local Retry",
                    detail: "Retrying localhost because \(endpoint.host):\(endpoint.port) did not answer the IBKR session cleanly."
                )
                self.connectToBroker(
                    endpoint: fallbackEndpoint,
                    maintainConnection: maintainConnection,
                    scanBurst: scanBurst,
                    attemptedLoopbackFallback: true,
                    observer: observer
                )
                return
            }

            if case .connected = event,
               attemptedLoopbackFallback,
               self.brokerHost != endpoint.host {
                self.brokerHost = endpoint.host
                self.appendLog(
                    title: "TWS Host Updated",
                    detail: "Saved localhost after a successful local IBKR retry."
                )
            }

            self.handleBrokerEvent(
                event,
                host: endpoint.host,
                port: endpoint.port,
                modeLabel: endpoint.modeLabel,
                accountID: endpoint.accountID
            )
            observer?(event)
        }
    }

    private func shouldRetryViaLoopback(
        after event: WealthIBKRBridgeEvent,
        endpoint: BrokerEndpoint,
        attemptedLoopbackFallback: Bool
    ) -> Bool {
#if targetEnvironment(macCatalyst)
        guard !attemptedLoopbackFallback else { return false }
        guard !isLoopbackHost(endpoint.host) else { return false }
        guard syncStatus == "CONNECTING" else { return false }

        switch event {
        case .failed, .disconnected:
            return true
        case .connecting, .connected, .quote:
            return false
        }
#else
        return false
#endif
    }

    private func isLoopbackHost(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "127.0.0.1" || normalized == "localhost" || normalized == "::1"
    }

    func recordCloudSyncEvent(title: String, detail: String) {
        appendLog(title: title, detail: detail)
        WealthEventLogStore.shared.record(title: title, detail: detail, category: "sync", tintName: "blue")
    }

    private func finishScanBurstCompletion() {
        scanBurstShutdownTask?.cancel()
        scanBurstShutdownTask = nil
        scanBurstCompletion?.resume()
        scanBurstCompletion = nil
    }
}
