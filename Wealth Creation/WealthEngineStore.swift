import SwiftUI
import Combine

@MainActor
final class WealthEngineStore: ObservableObject {
    static let shared = WealthEngineStore()

    static let defaultSoftRefreshMinutes = 10.0
    static let defaultHeavyRefreshMinutes = 30.0
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

    enum StorageKey {
        static let lastRecurringCycleLabel = "awc_engine_last_recurring_cycle_label"
        static let dailySoftCycleCount = "awc_engine_daily_soft_cycle_count"
        static let dailyHeavyCycleCount = "awc_engine_daily_heavy_cycle_count"
        static let dailyScanCycleDay = "awc_engine_daily_scan_cycle_day"
        static let recurringCycleCounterVersion = "awc_engine_recurring_cycle_counter_version"
        static let lightRefreshMinutes = "awc_scan_refresh_light_minutes"
        static let heavyRefreshMinutes = "awc_scan_refresh_heavy_minutes"
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

    enum LegacyStorageKey {
        static let lastRecurringCycleLabel = "awc_last_recurring_cycle_label"
        static let dailySoftCycleCount = "awc_daily_soft_cycle_count"
        static let dailyHeavyCycleCount = "awc_daily_heavy_cycle_count"
        static let dailyScanCycleDay = "awc_daily_scan_cycle_day"
    }

    @Published var rankedAssets: [Opportunity] = []
    @Published var scannedSignals: [MarketSignal] = []
    @Published var lastDecisionSummary = "AI online"
    @Published var lastRefresh: Date?
    @Published var lastHeavyRefresh: Date?
    @Published var brainSnapshot = WealthBrainSnapshot.placeholder
    @Published var activationStage = 0
    @Published var activationStageTotal = 2
    @Published var activationCycleComplete = false
    @Published var tradingLifecycleArmed = false
    @Published var lastRecurringCycleLabel = "WAITING"
    @Published var dailySoftCycleCount = 0
    @Published var dailyHeavyCycleCount = 0
    @Published var dashboardSnapshot: DashboardSnapshot?

    var softTimer: Timer?
    var heavyTimer: Timer?
    var activationTask: Task<Void, Never>?
    var pendingPublishTask: Task<Void, Never>?
    var hasBootstrapped = false
    var pendingRefreshPayload: PendingRefreshPayload?

    let defaults = UserDefaults.standard

    private init() {
        normalizeRecurringCycleStorageIfNeeded()
        normalizeScanRefreshSettingsIfNeeded()
        lastRecurringCycleLabel = resolvedRecurringCycleLabel()
        resetDailyCycleCountIfNeeded()
        dailySoftCycleCount = resolvedDailySoftCycleCount()
        dailyHeavyCycleCount = resolvedDailyHeavyCycleCount()
    }

    var configuredSoftRefreshMinutes: Double {
        let saved = defaults.object(forKey: StorageKey.lightRefreshMinutes) as? Double
        return max(Self.minimumSoftRefreshMinutes, saved ?? Self.defaultSoftRefreshMinutes)
    }

    var configuredHeavyRefreshMinutes: Double {
        let saved = defaults.object(forKey: StorageKey.heavyRefreshMinutes) as? Double
        return max(Self.minimumHeavyRefreshMinutes, saved ?? Self.defaultHeavyRefreshMinutes)
    }

    var dailySoftCycleCountLabel: String {
        "SOFT \(dailySoftCycleCount)"
    }

    var dailyHeavyCycleCountLabel: String {
        "HEAVY \(dailyHeavyCycleCount)"
    }

    func forceRefreshNow() {
        activationTask?.cancel()
        activationTask = nil
        pendingPublishTask?.cancel()
        pendingPublishTask = nil
        pendingRefreshPayload = nil
        activationStage = activationStageTotal
        activationCycleComplete = false
        tradingLifecycleArmed = false
        refresh(mode: .deep)
    }

    func restoreDashboardSnapshotFromCurrentStores() {
        let portfolio = WealthPortfolioStore.shared
        dashboardSnapshot = DashboardSnapshot(
            cashBalance: portfolio.brokerCashBalance,
            availableCapital: portfolio.availableCapital,
            committedCapital: portfolio.committedCapital,
            holdingsValue: portfolio.holdingsValue,
            accountValue: portfolio.totalAccountAmount,
            buyReserved: portfolio.totalBuyReservedCapital,
            sellReturning: portfolio.pendingSellReturnCapital,
            totalPnL: portfolio.totalPnL
        )
    }

    private func normalizeScanRefreshSettingsIfNeeded() {
        normalizeRefreshValue(
            key: StorageKey.lightRefreshMinutes,
            legacyDefault: Self.legacySoftRefreshMinutes,
            fallback: Self.defaultSoftRefreshMinutes,
            minimum: Self.minimumSoftRefreshMinutes
        )
        normalizeRefreshValue(
            key: StorageKey.heavyRefreshMinutes,
            legacyDefault: Self.legacyHeavyRefreshMinutes,
            fallback: Self.defaultHeavyRefreshMinutes,
            minimum: Self.minimumHeavyRefreshMinutes
        )
    }

    private func normalizeRefreshValue(
        key: String,
        legacyDefault: Double,
        fallback: Double,
        minimum: Double
    ) {
        guard let saved = defaults.object(forKey: key) as? Double else {
            defaults.set(fallback, forKey: key)
            return
        }

        if saved == legacyDefault || saved < minimum {
            defaults.set(fallback, forKey: key)
        }
    }
}
