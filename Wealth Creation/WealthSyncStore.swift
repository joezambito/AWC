import SwiftUI
import Combine

@MainActor
final class WealthSyncStore: ObservableObject {
    static let shared = WealthSyncStore()

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

    @Published var syncStatus: String
    @Published var lastPhoneSync: Date?
    @Published var lastMacSync: Date?
    @Published var syncLog: [SyncSnapshot]

    private let defaults = UserDefaults.standard

    private init() {
        macBridgeEnabled = defaults.object(forKey: StorageKey.macBridgeEnabled) as? Bool ?? true
        cloudSyncEnabled = defaults.object(forKey: StorageKey.cloudSyncEnabled) as? Bool ?? true
        brokerHost = defaults.string(forKey: StorageKey.brokerHost) ?? "127.0.0.1"
        brokerPort = defaults.object(forKey: StorageKey.brokerPort) as? Int ?? 7497
        liveMode = defaults.object(forKey: StorageKey.liveMode) as? Bool ?? false
        syncStatus = "TWS OFFLINE"
        lastPhoneSync = .now.addingTimeInterval(-18)
        lastMacSync = .now.addingTimeInterval(-63)
        syncLog = [
            SyncSnapshot(title: "Phone Push", detail: "Phone state pushed into the AWC core.", timestamp: .now.addingTimeInterval(-140)),
            SyncSnapshot(title: "Mac Pull", detail: "Mac bridge refreshed broker and scan state.", timestamp: .now.addingTimeInterval(-320))
        ]
    }

    func syncFromPhone() {
        lastPhoneSync = .now
        appendLog(title: "Phone Push", detail: "Phone state pushed into shared core.")
        WealthEventLogStore.shared.record(title: "Phone Sync", detail: "Phone state pushed into shared core.", category: "sync", tintName: "blue")
    }

    func syncFromMac() {
        lastMacSync = .now
        appendLog(title: "Mac Pull", detail: "Mac bridge updated broker and engine state.")
        WealthEventLogStore.shared.record(title: "Mac Sync", detail: "Mac bridge updated broker and engine state.", category: "sync", tintName: "blue")
    }

    func syncEverything() {
        lastPhoneSync = .now
        lastMacSync = .now
        appendLog(title: "Full Sync", detail: "Phone, Mac, broker, and core state aligned.")
        WealthEventLogStore.shared.record(title: "Full Sync", detail: "Phone, Mac, broker, and core state aligned.", category: "sync", tintName: "blue")
    }

    func connectBrokerAPI() {
        let accountID = WealthBrokerStore.shared.ibkrAccountID.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = brokerHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPort = (1...65535).contains(brokerPort) ? brokerPort : 7497
        let modeLabel = liveMode ? "live" : "paper"

        if brokerPort != resolvedPort {
            brokerPort = resolvedPort
        }

        syncStatus = "CONNECTING"
        appendLog(
            title: "TWS Probe",
            detail: "Trying \(modeLabel) TWS at \(host):\(resolvedPort) for \(accountID.isEmpty ? "NO ACCOUNT" : accountID)."
        )

        WealthIBKRBridge.shared.connect(host: host, port: resolvedPort) { [weak self] event in
            guard let self else { return }

            switch event {
            case .connecting:
                self.syncStatus = "CONNECTING"

            case .connected:
                self.syncStatus = self.liveMode ? "TWS LIVE" : "TWS PAPER"
                WealthBrokerStore.shared.clearBrokerFailureState()
                self.lastMacSync = .now
                self.appendLog(
                    title: "TWS Connected",
                    detail: "Connected to \(host):\(resolvedPort) for \(self.liveMode ? "live" : "paper") mode using \(accountID.isEmpty ? "NO ACCOUNT" : accountID)."
                )
                WealthEventLogStore.shared.record(title: "TWS Connected", detail: "Broker feed connected in \(self.liveMode ? "live" : "paper") mode.", category: "broker", tintName: "green")

            case .disconnected(let detail):
                self.syncStatus = "TWS OFFLINE"
                WealthBrokerQuoteStore.shared.clear()
                self.appendLog(title: "TWS Closed", detail: detail)
                WealthEventLogStore.shared.record(title: "TWS Offline", detail: detail, category: "broker", tintName: "orange")

            case .failed(let detail):
                self.syncStatus = "TWS FAILED"
                WealthBrokerStore.shared.recordBrokerFailure(detail)
                self.appendLog(title: "TWS Failed", detail: detail)
                WealthEventLogStore.shared.record(title: "TWS Failed", detail: detail, category: "broker", tintName: "red")

            case .quote(let quote):
                WealthBrokerQuoteStore.shared.ingest(quote)
            }
        }
    }

    func disconnectBrokerAPI() {
        WealthIBKRBridge.shared.disconnect()
        WealthBrokerQuoteStore.shared.clear()
        syncStatus = "TWS OFFLINE"
        WealthEventLogStore.shared.record(title: "TWS Disconnected", detail: "Broker link manually disconnected.", category: "broker", tintName: "orange")
    }

    private func appendLog(title: String, detail: String) {
        syncLog.insert(SyncSnapshot(title: title, detail: detail, timestamp: .now), at: 0)
        syncLog = Array(syncLog.prefix(8))
    }
}
