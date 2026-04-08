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
    var pendingPublishTask: Task<Void, Never>?
    var pendingMarketMaterializationTask: Task<Void, Never>?
    var scanProgressAnimationTask: Task<Void, Never>?
    var scanProgressAnimationEndsAt: Date?
    var hasBootstrapped = false
    var pendingRefreshPayload: PendingRefreshPayload?
    @Published var isMarketMaterializationInFlight = false {
        didSet {
            if oldValue != isMarketMaterializationInFlight {
                marketMaterializationUpdatedAt = .now
            }
        }
    }
    @Published var marketMaterializationUpdatedAt: Date = .distantPast

    let defaults = UserDefaults.standard
    var stagedDashboardSnapshot: DashboardSnapshot?
    var frozenRankedAssets: [Opportunity] = []
    var frozenScannedSignals: [MarketSignal] = []
    var frozenConfirmedHoldings: [Holding] = []
    var frozenPendingHoldings: [Holding] = []
    var frozenPendingOpportunities: [Opportunity] = []
    var frozenCompletedOpportunities: [Opportunity] = []
    private var didRestorePersistedMarketCache = false
    var warmStartRefreshTask: Task<Void, Never>?

    private init() {
        invalidatePersistedMarketCacheIfNeeded()
        normalizeRecurringCycleStorageIfNeeded()
        normalizeScanRefreshSettingsIfNeeded()
        normalizePersistedMarketCacheDecisionStatesIfNeeded()
        lastRecurringCycleLabel = resolvedRecurringCycleLabel()
        resetDailyCycleCountIfNeeded()
        dailySoftCycleCount = resolvedDailySoftCycleCount()
        dailyHeavyCycleCount = resolvedDailyHeavyCycleCount()
        if Self.rankedAssetsFileURL().flatMap({ FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }) != nil {
            defaults.removeObject(forKey: StorageKey.cachedRankedAssets)
        }
        if Self.scanUniverseFileURL().flatMap({ FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }) != nil {
            defaults.removeObject(forKey: StorageKey.cachedScanUniverse)
        }
    }
}
