import Combine
import Foundation

@MainActor
final class WealthCloudSyncCoordinator {
    static let shared = WealthCloudSyncCoordinator()
    private let featureEnabled = true

    private struct SharedStateSnapshot: Codable {
        let updatedAt: Date
        let sourceDevice: String
        let passcode: String?
        let brokerHost: String
        let brokerPort: Int
        let liveMode: Bool
        let macBridgeEnabled: Bool
        let cloudSyncEnabled: Bool
        let selectedBrokerName: String
        let lowestFeeFirst: Bool
        let smartRouting: Bool
        let ibkrAccountID: String
        let ibkrPaperBalance: Double
        let ibkrLiveBalance: Double
        let paperTradingEnabled: Bool
        let liveTradingEnabled: Bool
        let brokerDisplayModeRaw: String
        let externalDeposits: Double
        let protectedBaseCapital: Double
        let earnedProfit: Double
        let dailyProfit: Double
        let reservedOrderCapital: Double
        let holdings: [WealthPortfolioStore.PersistedHolding]
        let queuedOpportunities: [WealthPortfolioStore.PersistedOpportunity]
        let completedActivity: [WealthPortfolioStore.PersistedOpportunity]
        let saleGates: [WealthPortfolioStore.PersistedSaleGate]
        let rankedAssets: [WealthPortfolioStore.PersistedOpportunity]
        let lastRefresh: Date?
        let lastHeavyRefresh: Date?
    }

    private enum StorageKey {
        static let sharedState = "awc_cloud_shared_state_v1"
        static let passcode = "awc_root_passcode"
    }

    private let cloudStore = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var cancellables: Set<AnyCancellable> = []
    private var pendingPushTask: Task<Void, Never>?
    private var didActivate = false
    private var isApplyingRemoteSnapshot = false
    private var lastAppliedRemoteSnapshotAt: Date = .distantPast

    private init() {}

    func activate() {
        guard featureEnabled else { return }
        guard !didActivate else { return }
        didActivate = true

        observeSharedStateChanges()

        NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification,
            object: defaults
        )
        .sink { [weak self] _ in
            self?.schedulePush(reason: "local-defaults")
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
        .sink { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pullSharedState(reason: "remote-change")
            }
        }
        .store(in: &cancellables)

        cloudStore.synchronize()
        Task { @MainActor [weak self] in
            await self?.pullSharedState(reason: "launch")
            self?.schedulePush(reason: "launch")
        }
    }

    private func observeSharedStateChanges() {
        let trackedObjects: [ObservableObjectPublisher] = [
            WealthSyncStore.shared.objectWillChange,
            WealthBrokerStore.shared.objectWillChange,
            WealthPortfolioStore.shared.objectWillChange,
            WealthEngineStore.shared.objectWillChange,
            WealthAuthStore.shared.objectWillChange
        ]

        Publishers.MergeMany(trackedObjects)
            .sink { [weak self] _ in
                self?.schedulePush(reason: "shared-state")
            }
            .store(in: &cancellables)
    }

    func syncFromCurrentDevice() {
        guard featureEnabled else { return }
        guard WealthSyncStore.shared.cloudSyncEnabled else { return }
        pushSharedState(reason: "manual-push")
    }

    func syncToCurrentDevice() async {
        guard featureEnabled else { return }
        guard WealthSyncStore.shared.cloudSyncEnabled else { return }
        cloudStore.synchronize()
        await pullSharedState(reason: "manual-pull")
    }

    func syncRoundTrip() async {
        guard featureEnabled else { return }
        guard WealthSyncStore.shared.cloudSyncEnabled else { return }
        pushSharedState(reason: "manual-roundtrip")
        cloudStore.synchronize()
        await pullSharedState(reason: "manual-roundtrip")
    }

    private func schedulePush(reason: String) {
        guard featureEnabled else { return }
        guard WealthSyncStore.shared.cloudSyncEnabled else { return }
        guard !isApplyingRemoteSnapshot else { return }

        pendingPushTask?.cancel()
        pendingPushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, !Task.isCancelled else { return }
            self.pushSharedState(reason: reason)
        }
    }

    private func pushSharedState(reason: String) {
        guard featureEnabled else { return }
        guard WealthSyncStore.shared.cloudSyncEnabled else { return }
        guard !isApplyingRemoteSnapshot else { return }

        let snapshot = makeSnapshot()
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }

        cloudStore.set(encoded, forKey: StorageKey.sharedState)
        cloudStore.synchronize()

        let syncStore = WealthSyncStore.shared
        if isRunningOnMac {
            syncStore.lastMacSync = .now
        } else {
            syncStore.lastPhoneSync = .now
        }
        syncStore.recordCloudSyncEvent(
            title: "Cloud Push",
            detail: "\(snapshot.sourceDevice) pushed shared state via \(reason)."
        )
    }

    private func pullSharedState(reason: String) async {
        guard featureEnabled else { return }
        guard WealthSyncStore.shared.cloudSyncEnabled else { return }
        guard let encoded = cloudStore.data(forKey: StorageKey.sharedState) else { return }
        guard let snapshot = try? JSONDecoder().decode(SharedStateSnapshot.self, from: encoded) else { return }
        guard snapshot.updatedAt > lastAppliedRemoteSnapshotAt else { return }
        guard snapshot.sourceDevice != localDeviceLabel else { return }

        isApplyingRemoteSnapshot = true
        defer { isApplyingRemoteSnapshot = false }

        apply(snapshot)
        lastAppliedRemoteSnapshotAt = snapshot.updatedAt

        let syncStore = WealthSyncStore.shared
        if isRunningOnMac {
            syncStore.lastPhoneSync = snapshot.updatedAt
        } else {
            syncStore.lastMacSync = snapshot.updatedAt
        }
        syncStore.recordCloudSyncEvent(
            title: "Cloud Pull",
            detail: "\(localDeviceLabel) applied shared state from \(snapshot.sourceDevice) via \(reason)."
        )
    }

    private func makeSnapshot() -> SharedStateSnapshot {
        let sync = WealthSyncStore.shared
        let broker = WealthBrokerStore.shared
        let portfolio = WealthPortfolioStore.shared
        let engine = WealthEngineStore.shared

        return SharedStateSnapshot(
            updatedAt: .now,
            sourceDevice: localDeviceLabel,
            passcode: defaults.string(forKey: StorageKey.passcode),
            brokerHost: sync.brokerHost,
            brokerPort: sync.brokerPort,
            liveMode: sync.liveMode,
            macBridgeEnabled: sync.macBridgeEnabled,
            cloudSyncEnabled: sync.cloudSyncEnabled,
            selectedBrokerName: broker.selectedBroker.name,
            lowestFeeFirst: broker.lowestFeeFirst,
            smartRouting: broker.smartRouting,
            ibkrAccountID: broker.ibkrAccountID,
            ibkrPaperBalance: broker.ibkrPaperBalance,
            ibkrLiveBalance: broker.ibkrLiveBalance,
            paperTradingEnabled: broker.paperTradingEnabled,
            liveTradingEnabled: broker.liveTradingEnabled,
            brokerDisplayModeRaw: broker.brokerDisplayMode.rawValue,
            externalDeposits: portfolio.externalDeposits,
            protectedBaseCapital: portfolio.protectedBaseCapital,
            earnedProfit: portfolio.earnedProfit,
            dailyProfit: portfolio.dailyProfit,
            reservedOrderCapital: portfolio.reservedOrderCapital,
            holdings: portfolio.holdings.map(WealthPortfolioStore.persistedHolding(from:)),
            queuedOpportunities: portfolio.queuedOpportunities.map(WealthPortfolioStore.persistedOpportunity(from:)),
            completedActivity: portfolio.completedActivity.map(WealthPortfolioStore.persistedOpportunity(from:)),
            saleGates: Array(portfolio.saleGates.values),
            rankedAssets: Array(engine.rankedAssets.prefix(120)).map(WealthPortfolioStore.persistedOpportunity(from:)),
            lastRefresh: engine.lastRefresh,
            lastHeavyRefresh: engine.lastHeavyRefresh
        )
    }

    private func apply(_ snapshot: SharedStateSnapshot) {
        let sync = WealthSyncStore.shared
        sync.macBridgeEnabled = snapshot.macBridgeEnabled
        sync.cloudSyncEnabled = snapshot.cloudSyncEnabled
        // Broker endpoint selection is device-local so phone/mac sync cannot overwrite a working TWS socket.
        // This preserves the active machine's host/port/live-mode wiring even when other devices push stale values.

        let broker = WealthBrokerStore.shared
        if let profile = broker.registry.first(where: { $0.name == snapshot.selectedBrokerName }) {
            broker.select(profile)
        }
        broker.lowestFeeFirst = snapshot.lowestFeeFirst
        broker.smartRouting = snapshot.smartRouting
        broker.ibkrAccountID = snapshot.ibkrAccountID
        broker.ibkrPaperBalance = snapshot.ibkrPaperBalance
        broker.ibkrLiveBalance = snapshot.ibkrLiveBalance
        broker.paperTradingEnabled = snapshot.paperTradingEnabled
        broker.liveTradingEnabled = snapshot.liveTradingEnabled
        broker.brokerDisplayMode = WealthBrokerStore.BrokerDisplayMode(rawValue: snapshot.brokerDisplayModeRaw) ?? .off
        broker.persistRouting()

        if let passcode = snapshot.passcode, passcode.count == 6 {
            WealthAuthStore.shared.resetPasscode(passcode)
        }

        let portfolio = WealthPortfolioStore.shared
        portfolio.externalDeposits = snapshot.externalDeposits
        portfolio.protectedBaseCapital = snapshot.protectedBaseCapital
        portfolio.earnedProfit = snapshot.earnedProfit
        portfolio.dailyProfit = snapshot.dailyProfit
        portfolio.reservedOrderCapital = snapshot.reservedOrderCapital
        portfolio.holdings = snapshot.holdings.map(WealthPortfolioStore.restorePersistedHolding(from:))
        portfolio.queuedOpportunities = snapshot.queuedOpportunities.map(WealthPortfolioStore.restorePersistedOpportunity(from:))
        portfolio.completedActivity = WealthPortfolioStore.prunedCompletedActivity(
            snapshot.completedActivity.map(WealthPortfolioStore.restorePersistedOpportunity(from:))
        )
        portfolio.saleGates = snapshot.saleGates.reduce(into: [String: WealthPortfolioStore.PersistedSaleGate]()) { partialResult, item in
            partialResult[item.key] = item
        }

        WealthEngineStore.shared.applySharedVisibleSnapshot(
            snapshot.rankedAssets.map(WealthPortfolioStore.restorePersistedOpportunity(from:)),
            refreshTime: snapshot.lastRefresh,
            heavyRefreshTime: snapshot.lastHeavyRefresh
        )
    }

    private var localDeviceLabel: String {
        isRunningOnMac ? "MAC" : "PHONE"
    }

    private var isRunningOnMac: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }
}
