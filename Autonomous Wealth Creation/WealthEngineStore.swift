import SwiftUI
import Combine

@MainActor
final class WealthEngineStore: ObservableObject {
    static let shared = WealthEngineStore()

    static let defaultSoftRefreshMinutes = 10.0
    static let defaultHeavyRefreshMinutes = 30.0
    static let lockedCheckpointCount = 6
    static let aiLivePromotionMinimumProgress = 0.75
    static let activityPromotionMinimumProgress = 1.0
    static let fixedIBKRCheckpointMinutes = [9, 19, 29]
    static let fixedSoftCheckpointMinutes = [10, 20]
    static let fixedHeavyCheckpointMinutes = [30]
    static let phoneActivationStageCount = 2
    static let legacySoftRefreshMinutes = 10.0
    static let legacyHeavyRefreshMinutes = 30.0
    static let minimumSoftRefreshMinutes = 2.0
    static let minimumHeavyRefreshMinutes = 5.0

    struct DashboardSnapshot {
        let cashBalance: Double
        let availableCapital: Double
        let committedCapital: Double
        let holdingsValue: Double
        let accountValue: Double
        let buyReserved: Double
        let sellReturning: Double
        let totalPnL: Double
    }

    struct PendingRefreshPayload {
        let opportunities: [Opportunity]
        let mode: RefreshMode
        let refreshTime: Date
        let buyingPower: Double
        let goals: WealthGoalVector
        let regime: WealthMarketRegime
        let brainMode: WealthAggressionMode
        let hungerMode: WealthHungerMode
        let scannedSignals: [MarketSignal]
    }

    enum RefreshMode {
        case startup
        case quick
        case soft
        case heavy
        case deep
    }

    enum StartupSequencePhase: Equatable {
        case idle
        case waitingToScan
        case universeRefreshRunning
        case aiScanRunning
        case postScanHold
        case marketWarmupRunning
    }

    enum StorageKey {
        static let persistedMarketCacheVersion = "awc_engine_persisted_market_cache_version"
        static let lastRecurringCycleLabel = "awc_engine_last_recurring_cycle_label"
        static let dailySoftCycleCount = "awc_engine_daily_soft_cycle_count"
        static let dailyHeavyCycleCount = "awc_engine_daily_heavy_cycle_count"
        static let dailyScanCycleDay = "awc_engine_daily_scan_cycle_day"
        static let recurringCycleCounterVersion = "awc_engine_recurring_cycle_counter_version"
        static let lightRefreshMinutes = "awc_scan_refresh_light_minutes"
        static let heavyRefreshMinutes = "awc_scan_refresh_heavy_minutes"
        static let cachedRankedAssets = "awc_engine_cached_ranked_assets_v1"
        static let cachedScanUniverse = "awc_engine_cached_scan_universe_v1"
        static let cachedAILiveResults = "awc_engine_cached_ai_live_results_v1"
        static let cachedLastRefresh = "awc_engine_cached_last_refresh_v1"
        static let cachedLastHeavyRefresh = "awc_engine_cached_last_heavy_refresh_v1"
        static let scanUS = "awc_scan_market_nasdaq"
        static let scanASX = "awc_scan_market_asx"
        static let scanCanada = "awc_scan_market_canada"
        static let scanEurope = "awc_scan_market_europe"
        static let scanAsia = "awc_scan_market_asia"
        static let scanMiddleEast = "awc_scan_market_middleeast"
        static let scanRussia = "awc_scan_market_russia"
        static let scanLatam = "awc_scan_market_latam"
        static let scanAfrica = "awc_scan_market_africa"
        static let scanFX = "awc_scan_market_forex"
        static let scanCrypto = "awc_scan_market_crypto"
        static let scanCommodities = "awc_scan_market_commodities"
    }

    private enum CacheConstants {
        static let persistedMarketCacheVersion = 2
        static let rankedAssetsFileName = "engine_ranked_assets_v1.json"
        static let scanUniverseFileName = "engine_scan_universe_v1.json"
    }

    enum LegacyStorageKey {
        static let lastRecurringCycleLabel = "awc_last_recurring_cycle_label"
        static let dailySoftCycleCount = "awc_daily_soft_cycle_count"
        static let dailyHeavyCycleCount = "awc_daily_heavy_cycle_count"
        static let dailyScanCycleDay = "awc_daily_scan_cycle_day"
    }

    @Published var rankedAssets: [Opportunity] = []
    var scanUniverse: [Opportunity] = []
    @Published var scannedSignals: [MarketSignal] = []
    @Published var lastDecisionSummary = "AI online"
    @Published var lastRefresh: Date?
    @Published var lastHeavyRefresh: Date?
    @Published var startupSequencePhase: StartupSequencePhase = .idle {
        didSet {
            if oldValue != startupSequencePhase {
                startupSequenceUpdatedAt = .now
            }
        }
    }
    @Published var startupSequenceUpdatedAt: Date = .distantPast
    @Published var brainSnapshot = WealthBrainSnapshot.placeholder
    @Published var activationStage = 0
    @Published var activationStageTotal = 2
    @Published var activationCycleComplete = false
    @Published var lockedCheckpointProgress = 0
    @Published var tradingLifecycleArmed = false
    @Published var downstreamRecoveryPending = false
    @Published var lastRecurringCycleLabel = "WAITING"
    @Published var dailySoftCycleCount = 0
    @Published var dailyHeavyCycleCount = 0
    @Published var dashboardSnapshot: DashboardSnapshot?
    @Published var appOpenUpdatedAt: Date?
    @Published var cacheRestoreUpdatedAt: Date?
    @Published var isDashboardRefreshInFlight = false {
        didSet {
            if oldValue != isDashboardRefreshInFlight {
                dashboardRefreshUpdatedAt = .now
            }
        }
    }
    @Published var dashboardRefreshUpdatedAt: Date = .distantPast
    @Published var isUsingCachedMarketData = false
    @Published var aiLiveResultsByKey: [String: WealthAILiveResult] = [:]
    @Published var activityRefusalsByKey: [String: WealthActivityRefusalHandoff] = [:]

    var softTimer: Timer?
    var heavyTimer: Timer?
    var preScanBurstTimer: Timer?
    var scheduledCheckpointTimer: Timer?
    var activationTask: Task<Void, Never>?
    var warmStartRefreshTask: Task<Void, Never>?
    var pendingMarketMaterializationTask: Task<Void, Never>?
    var scanProgressAnimationTask: Task<Void, Never>?
    var pendingPublishTask: Task<Void, Never>?
    var isMarketMaterializationInFlight = false
    @Published var marketMaterializationUpdatedAt: Date = .distantPast

    var hasBootstrapped = false
    var scanProgressAnimationEndsAt: Date?
    var configuredSoftRefreshMinutes: Double = WealthEngineStore.defaultSoftRefreshMinutes
    var didRestorePersistedMarketCache = false
    var pendingRefreshPayload: PendingRefreshPayload?

    var stagedDashboardSnapshot: DashboardSnapshot?
    var frozenRankedAssets: [Opportunity] = []
    var frozenScannedSignals: [MarketSignal] = []
    var frozenConfirmedHoldings: [Holding] = []
    var frozenPendingHoldings: [Holding] = []
    var frozenPendingOpportunities: [Opportunity] = []
    var frozenCompletedOpportunities: [Opportunity] = []

    let defaults = UserDefaults.standard

    private init() {}
}

// MARK: - Cache / State

extension WealthEngineStore {

    func restorePersistedMarketCacheIfNeeded() {
        guard !didRestorePersistedMarketCache else { return }
        didRestorePersistedMarketCache = true

        let defaults = self.defaults
        let storedVersion = defaults.integer(forKey: StorageKey.persistedMarketCacheVersion)
        guard storedVersion >= CacheConstants.persistedMarketCacheVersion else {
            defaults.set(CacheConstants.persistedMarketCacheVersion, forKey: StorageKey.persistedMarketCacheVersion)
            return
        }

        var restoredCachedData = false
        var normalizedScanUniverseFromCache = false

        let rankedDecoder = JSONDecoder()
        rankedDecoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )

        let hasUsableRankedSnapshot: Bool
        if let data = Self.loadPersistedRankedAssetsData(from: defaults),
           let payload = try? rankedDecoder.decode([WealthPortfolioStore.PersistedOpportunity].self, from: data) {
            rankedAssets = payload
                .map(WealthPortfolioStore.restorePersistedOpportunity(from:))
                .map(WealthAllCardsStore.normalizePermissionForColorRule)
            hasUsableRankedSnapshot = !payload.isEmpty
            restoredCachedData = restoredCachedData || hasUsableRankedSnapshot
        } else {
            hasUsableRankedSnapshot = false
        }

        if !hasUsableRankedSnapshot {
            defaults.removeObject(forKey: StorageKey.cachedRankedAssets)
            if let cacheURL = Self.rankedAssetsFileURL() {
                try? FileManager.default.removeItem(at: cacheURL)
            }
        }

        let hasUsableFullUniverseSnapshot: Bool = hasUsableRankedSnapshot

        if hasUsableFullUniverseSnapshot,
           let data = Self.loadPersistedScanUniverseData(from: defaults),
           let payload = try? rankedDecoder.decode([WealthPortfolioStore.PersistedOpportunity].self, from: data) {
            scanUniverse = payload
                .map(WealthPortfolioStore.restorePersistedOpportunity(from:))
                .map(WealthAllCardsStore.normalizePermissionForColorRule)
            normalizedScanUniverseFromCache = !payload.isEmpty
            restoredCachedData = restoredCachedData || !payload.isEmpty
        }

        if !hasUsableFullUniverseSnapshot {
            defaults.removeObject(forKey: StorageKey.cachedScanUniverse)
            if let cacheURL = Self.scanUniverseFileURL() {
                try? FileManager.default.removeItem(at: cacheURL)
            }
        }

        let aiLiveDecoder = JSONDecoder()
        aiLiveDecoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )

        if let data = defaults.data(forKey: StorageKey.cachedAILiveResults),
           let payload = try? aiLiveDecoder.decode([WealthAILiveResult].self, from: data) {
            aiLiveResultsByKey = payload.reduce(into: [String: WealthAILiveResult]()) { partialResult, item in
                partialResult[item.key] = item
            }
        }

        lastRefresh = defaults.object(forKey: StorageKey.cachedLastRefresh) as? Date
        lastHeavyRefresh = defaults.object(forKey: StorageKey.cachedLastHeavyRefresh) as? Date
        isUsingCachedMarketData = restoredCachedData

        let refreshTime = lastRefresh
        let portfolio = WealthPortfolioStore.shared
        let activityKeys = Set(portfolio.activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
        let holdingKeys = Set(
            portfolio.holdings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
        let cachedUniverse = rankedAssets.isEmpty ? scanUniverse : rankedAssets
        if !shouldTrustCachedLivePromotionState() {
            aiLiveResultsByKey = [:]
        }
        let livePickKeys = WealthAllCardsStore.visibleLivePickKeys(
            from: cachedUniverse,
            aiLiveResults: aiLiveResultsByKey,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            spendableCash: portfolio.freeBuyingPower
        )
        WealthAllCardsStore.shared.sync(
            opportunities: cachedUniverse,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: livePickKeys,
            refreshTime: refreshTime
        )
        downstreamRecoveryPending = requiresDownstreamLiveRecovery()

        if normalizedScanUniverseFromCache {
            persistMarketCache()
        }
    }

    func persistMarketCache() {
        persistMarketCacheSnapshot(
            rankedAssets: rankedAssets,
            scanUniverse: scanUniverse,
            aiLiveResultsByKey: aiLiveResultsByKey,
            lastRefresh: lastRefresh,
            lastHeavyRefresh: lastHeavyRefresh
        )
    }

    func persistMarketCacheSnapshot(
        rankedAssets: [Opportunity],
        scanUniverse: [Opportunity],
        aiLiveResultsByKey: [String: WealthAILiveResult],
        lastRefresh: Date?,
        lastHeavyRefresh: Date?
    ) {
        let rankedPayload = rankedAssets.map(WealthPortfolioStore.persistedOpportunity(from:))
        let scanPayload = scanUniverse.map(WealthPortfolioStore.persistedOpportunity(from:))
        let rankedEncoder = JSONEncoder()
        rankedEncoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        if let data = try? rankedEncoder.encode(rankedPayload) {
            Self.persistRankedAssetsData(data)
            defaults.removeObject(forKey: StorageKey.cachedRankedAssets)
        }
        if let data = try? rankedEncoder.encode(scanPayload) {
            Self.persistScanUniverseData(data)
            defaults.removeObject(forKey: StorageKey.cachedScanUniverse)
        }

        let aiLivePayload = Array(aiLiveResultsByKey.values)
        let aiLiveEncoder = JSONEncoder()
        aiLiveEncoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        if let data = try? aiLiveEncoder.encode(aiLivePayload) {
            defaults.set(data, forKey: StorageKey.cachedAILiveResults)
        }

        defaults.set(lastRefresh, forKey: StorageKey.cachedLastRefresh)
        defaults.set(lastHeavyRefresh, forKey: StorageKey.cachedLastHeavyRefresh)
        defaults.synchronize()
    }

    func resetCachedRuntimeStateToZero() {
        softTimer?.invalidate()
        heavyTimer?.invalidate()
        softTimer = nil
        heavyTimer = nil
        activationTask?.cancel()
        activationTask = nil
        warmStartRefreshTask?.cancel()
        warmStartRefreshTask = nil
        pendingMarketMaterializationTask?.cancel()
        pendingMarketMaterializationTask = nil
        isMarketMaterializationInFlight = false

        rankedAssets = []
        scanUniverse = []
        scannedSignals = []
        lastRefresh = nil
        lastHeavyRefresh = nil
        startupSequencePhase = .idle
        startupSequenceUpdatedAt = .distantPast
        brainSnapshot = .placeholder
        activationStage = 0
        activationCycleComplete = false
        lockedCheckpointProgress = 0
        tradingLifecycleArmed = false
        downstreamRecoveryPending = false
        lastDecisionSummary = "AI online"
        dashboardSnapshot = nil
        appOpenUpdatedAt = nil
        cacheRestoreUpdatedAt = nil
        isDashboardRefreshInFlight = false
        dashboardRefreshUpdatedAt = .distantPast
        isUsingCachedMarketData = false
        aiLiveResultsByKey = [:]
        activityRefusalsByKey = [:]
        marketMaterializationUpdatedAt = .distantPast

        stagedDashboardSnapshot = nil
        frozenRankedAssets = []
        frozenScannedSignals = []
        frozenConfirmedHoldings = []
        frozenPendingHoldings = []
        frozenPendingOpportunities = []
        frozenCompletedOpportunities = []

        defaults.removeObject(forKey: StorageKey.cachedRankedAssets)
        defaults.removeObject(forKey: StorageKey.cachedScanUniverse)
        defaults.removeObject(forKey: StorageKey.cachedAILiveResults)
        defaults.removeObject(forKey: StorageKey.cachedLastRefresh)
        defaults.removeObject(forKey: StorageKey.cachedLastHeavyRefresh)
        if let cacheURL = Self.rankedAssetsFileURL() {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        if let cacheURL = Self.scanUniverseFileURL() {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        didRestorePersistedMarketCache = false

        WealthBrainStore.shared.resetToPlaceholder()
    }

    func applySharedVisibleSnapshot(
        _ sharedCards: [Opportunity],
        refreshTime: Date?,
        heavyRefreshTime: Date?
    ) {
        let portfolio = WealthPortfolioStore.shared
        let activityKeys = Set(portfolio.activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
        let holdingKeys = Set(
            portfolio.holdings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
        let livePickKeys = WealthAllCardsStore.visibleLivePickKeys(
            from: sharedCards,
            aiLiveResults: aiLiveResultsByKey,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            spendableCash: portfolio.freeBuyingPower
        )

        scanUniverse = sharedCards
        rankedAssets = sharedCards
        lastRefresh = refreshTime
        lastHeavyRefresh = heavyRefreshTime
        isUsingCachedMarketData = !sharedCards.isEmpty

        WealthDataAliveStore.shared.sync(cards: sharedCards, refreshTime: refreshTime)
        WealthAIScoreStore.shared.sync(cards: sharedCards, refreshTime: refreshTime)
        WealthConfidenceStore.shared.sync(cards: sharedCards, refreshTime: refreshTime)
        WealthAllCardsStore.shared.sync(
            opportunities: sharedCards,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: livePickKeys,
            refreshTime: refreshTime
        )
        persistMarketCache()
        restoreDashboardSnapshotFromCurrentStores()
    }

    private static func loadPersistedScanUniverseData(from defaults: UserDefaults) -> Data? {
        if let fileURL = scanUniverseFileURL(),
           let fileData = try? Data(contentsOf: fileURL) {
            return fileData
        }

        guard let stored = defaults.data(forKey: StorageKey.cachedScanUniverse) else {
            return nil
        }

        persistScanUniverseData(stored)
        defaults.removeObject(forKey: StorageKey.cachedScanUniverse)
        return stored
    }

    private static func loadPersistedRankedAssetsData(from defaults: UserDefaults) -> Data? {
        if let fileURL = rankedAssetsFileURL(),
           let fileData = try? Data(contentsOf: fileURL) {
            defaults.removeObject(forKey: StorageKey.cachedRankedAssets)
            return fileData
        }

        guard let stored = defaults.data(forKey: StorageKey.cachedRankedAssets) else {
            return nil
        }

        persistRankedAssetsData(stored)
        defaults.removeObject(forKey: StorageKey.cachedRankedAssets)
        return stored
    }

    private static func persistRankedAssetsData(_ data: Data) {
        guard let fileURL = rankedAssetsFileURL() else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func persistScanUniverseData(_ data: Data) {
        guard let fileURL = scanUniverseFileURL() else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func rankedAssetsFileURL() -> URL? {
        guard let baseURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        return baseURL
            .appendingPathComponent("WealthCreationCache", isDirectory: true)
            .appendingPathComponent(CacheConstants.rankedAssetsFileName)
    }

    private static func scanUniverseFileURL() -> URL? {
        guard let baseURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        return baseURL
            .appendingPathComponent("WealthCreationCache", isDirectory: true)
            .appendingPathComponent(CacheConstants.scanUniverseFileName)
    }

    private func prepareWarmStartMaterializedState() {
        let portfolio = WealthPortfolioStore.shared
        let universeStore = WealthMarketUniverseStore.shared
        let quoteStore = WealthBrokerQuoteStore.shared
        let snapshotStore = WealthPreparedSnapshotStore.shared
        let marketCandidates = WealthAllCardsStore.shared.currentMarketCards(preferredRefreshTime: lastRefresh)

        snapshotStore.invalidatePreparedMarkets()
        snapshotStore.refreshMarkets(
            engine: self,
            portfolio: portfolio,
            universeStore: universeStore,
            quoteStore: quoteStore
        )
        WealthMarketViewCycleStore.shared.syncCycle(
            candidates: marketCandidates,
            cycleMarker: lastRefresh
        )
        snapshotStore.refreshCore(engine: self, portfolio: portfolio)

        if !marketCandidates.isEmpty {
            marketMaterializationUpdatedAt = .now
        }
    }

    func refreshDownstreamPromotionStateAfterStartupGate() async {
        guard activityPromotionGateSatisfied else { return }

        let currentUniverse = rankedAssets.isEmpty ? scanUniverse : rankedAssets
        guard !currentUniverse.isEmpty else { return }

        let portfolio = WealthPortfolioStore.shared
        let protection = WealthProtectionSettingsStore.shared

        portfolio.normalizeRuntimeBalancesIfNeeded()

        let finalRankedAssets = portfolio.reconcileEngineState(
            opportunities: currentUniverse,
            mode: .startup,
            protection: protection,
            allowNewOrders: tradingLifecycleArmed && activityPromotionGateSatisfied
        )
        let activityKeys = Set(portfolio.activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
        let holdingKeys = Set(
            portfolio.holdings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
        let livePickKeys = WealthAllCardsStore.visibleLivePickKeys(
            from: finalRankedAssets,
            aiLiveResults: aiLiveResultsByKey,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            spendableCash: portfolio.freeBuyingPower
        )

        rankedAssets = finalRankedAssets
        scanUniverse = finalRankedAssets

        portfolio.setReservedOrderCapital(
            portfolio.pendingBuyReserveCapital + portfolio.queuedBuyReserveCapital
        )
        portfolio.applySnapshot(from: finalRankedAssets)
        WealthAllCardsStore.shared.sync(
            opportunities: finalRankedAssets,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: livePickKeys,
            refreshTime: lastRefresh
        )

        prepareWarmStartMaterializedState()
        if let pendingMarketMaterializationTask {
            await pendingMarketMaterializationTask.value
        }

        downstreamRecoveryPending = false
        persistMarketCache()
        restoreDashboardSnapshotFromCurrentStores()
    }
}
