import Foundation

extension WealthEngineStore {
    private func invalidatePersistedMarketCacheIfNeeded() {
        let storedVersion = defaults.object(forKey: StorageKey.persistedMarketCacheVersion) as? Int ?? 0
        guard storedVersion != CacheConstants.persistedMarketCacheVersion else { return }

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
        defaults.set(CacheConstants.persistedMarketCacheVersion, forKey: StorageKey.persistedMarketCacheVersion)
    }

    func restorePersistedMarketCacheIfNeeded() {
        let visibleCachesMissing =
            WealthAllCardsStore.shared.reviewCards.isEmpty &&
            WealthAllCardsStore.shared.marketCards.isEmpty
        let engineCachesMissing = rankedAssets.isEmpty && scanUniverse.isEmpty

        guard !didRestorePersistedMarketCache || visibleCachesMissing || engineCachesMissing else { return }
        didRestorePersistedMarketCache = true
        restorePersistedMarketCache()
        if hasUsableWarmStartCardCache {
            restoreDashboardSnapshotFromCurrentStores()
        }
    }

    func invalidatePersistedMarketRestoreGuard() {
        didRestorePersistedMarketCache = false
    }

    var startupSequenceInFlight: Bool {
        activationTask != nil || startupSequencePhase != .idle
    }

    var startupAllowsLiveMarketUpdates: Bool {
        switch startupSequencePhase {
        case .idle:
            return true
        case .aiScanRunning, .marketWarmupRunning:
            return true
        case .waitingToScan, .postScanHold, .universeRefreshRunning:
            return false
        }
    }

    var startupAllowsUniverseRefresh: Bool {
        switch startupSequencePhase {
        case .idle, .universeRefreshRunning:
            return true
        case .waitingToScan, .aiScanRunning, .postScanHold, .marketWarmupRunning:
            return false
        }
    }

    var startupPostSequenceReady: Bool {
        activationTask == nil &&
        !startupSequenceInFlight &&
        activationCycleComplete &&
        tradingLifecycleArmed &&
        !downstreamRecoveryPending
    }

    var startupPromotionProgress: Double {
        if downstreamRecoveryPending {
            let currentCheckpoint = max(lockedCheckpointProgress, activationStage)
            return min(1, Double(currentCheckpoint) / Double(Self.lockedCheckpointCount))
        }

        if activationCycleComplete || tradingLifecycleArmed {
            return 1
        }

        let startupActive = activationTask != nil || startupSequenceInFlight
        guard startupActive else { return 1 }

        let currentCheckpoint = max(lockedCheckpointProgress, activationStage)
        return min(1, Double(currentCheckpoint) / Double(Self.lockedCheckpointCount))
    }

    var aiLivePromotionGateSatisfied: Bool {
        startupPromotionProgress >= Self.aiLivePromotionMinimumProgress
    }

    var activityPromotionGateSatisfied: Bool {
        startupPromotionProgress >= Self.activityPromotionMinimumProgress
    }

    private var downstreamRecoveryStaleInterval: TimeInterval { 5 * 60 }

    private func hasFreshDownstreamRefresh(now: Date = .now) -> Bool {
        guard let lastRefresh else { return false }
        return now.timeIntervalSince(lastRefresh) <= downstreamRecoveryStaleInterval
    }

    private func shouldTrustCachedLivePromotionState(now: Date = .now) -> Bool {
        hasFreshDownstreamRefresh(now: now) && !aiLiveResultsByKey.isEmpty
    }

    func requiresDownstreamLiveRecovery(now: Date = .now) -> Bool {
        guard hasUsableWarmStartCardCache else { return false }
        guard !hasFreshDownstreamRefresh(now: now) else {
            let portfolio = WealthPortfolioStore.shared
            let activityKeys = Set(portfolio.activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
            let holdingKeys = Set(
                portfolio.holdings
                    .filter { $0.orderState != .filled }
                    .map(WealthOpportunityLaneRules.laneKey)
            )
            let marketCards = WealthAllCardsStore.shared.currentMarketCards(preferredRefreshTime: lastRefresh)
            let aiLiveCandidates = WealthOpportunityLaneRules.aiLiveMarketRequestSet(
                from: marketCards,
                activityKeys: activityKeys,
                holdingKeys: holdingKeys,
                limit: WealthAllCardsStore.marketCardLimit
            )

            if !aiLiveCandidates.isEmpty && aiLiveResultsByKey.isEmpty {
                return true
            }

            if aiLiveCandidates.contains(where: { aiLiveResultsByKey[WealthOpportunityLaneRules.laneKey($0)] == nil }) {
                return true
            }

            if portfolio.activityOpportunities.contains(where: { !$0.hasFreshPromotionRefresh }) {
                return true
            }

            if portfolio.activityOpportunities.contains(where: {
                aiLiveResultsByKey[WealthOpportunityLaneRules.laneKey($0)] == nil
            }) {
                return true
            }

            return false
        }

        return true
    }

    var configuredSoftRefreshMinutes: Double {
        Self.defaultSoftRefreshMinutes
    }

    var configuredHeavyRefreshMinutes: Double {
        Self.defaultHeavyRefreshMinutes
    }

    var dailySoftCycleCountLabel: String {
        "SOFT \(dailySoftCycleCount)"
    }

    var dailyHeavyCycleCountLabel: String {
        "HEAVY \(dailyHeavyCycleCount)"
    }

    func markAppOpenForStartup() {
        appOpenUpdatedAt = .now
        startupSequenceUpdatedAt = .now
        if startupSequencePhase == .idle {
            activationCycleComplete = false
            lockedCheckpointProgress = 0
            tradingLifecycleArmed = false
        }
    }

    func forceRefreshNow() {
        activationTask?.cancel()
        activationTask = nil
        startupSequencePhase = .idle
        pendingMarketMaterializationTask?.cancel()
        pendingMarketMaterializationTask = nil
        isMarketMaterializationInFlight = false
        beginDashboardRefreshFreezeIfNeeded()
        activationStage = activationStageTotal
        activationCycleComplete = false
        lockedCheckpointProgress = 0
        tradingLifecycleArmed = false
        downstreamRecoveryPending = false
        appOpenUpdatedAt = .now
        startupSequenceUpdatedAt = .now
        marketMaterializationUpdatedAt = .distantPast
        refresh(mode: .deep)
    }

    func restoreDashboardSnapshotFromCurrentStores() {
        let portfolio = WealthPortfolioStore.shared
        let money = portfolio.runtimeMoneySnapshot
        dashboardSnapshot = DashboardSnapshot(
            cashBalance: money.cashBalance,
            availableCapital: money.availableCapital,
            committedCapital: money.committedCapital,
            holdingsValue: money.holdingsValue,
            accountValue: money.accountValue,
            buyReserved: money.buyReserved,
            sellReturning: money.sellReturning,
            totalPnL: money.totalPnL
        )
        WealthMoneyTraceLogger.log(
            stage: "dashboard_restore",
            snapshot: money,
            marketCandidates: WealthAllCardsStore.shared.marketCards.count
        )
    }


    var hasUsableWarmStartCardCache: Bool {
        let hasVisibleCards =
            !WealthAllCardsStore.shared.reviewCards.isEmpty ||
            !WealthAllCardsStore.shared.marketCards.isEmpty
        let hasEngineCards = !rankedAssets.isEmpty || !scanUniverse.isEmpty
        let hasRefreshMarker = lastRefresh != nil || cacheRestoreUpdatedAt != nil
        return (hasVisibleCards || hasEngineCards) && hasRefreshMarker
    }

    func applyWarmStartVisibleState() {
        let recoveryRequired = requiresDownstreamLiveRecovery()
        activationStageTotal = prefersFullSpeedActivation ? 1 : Self.phoneActivationStageCount
        activationStage = recoveryRequired ? 0 : activationStageTotal
        activationCycleComplete = !recoveryRequired
        lockedCheckpointProgress = recoveryRequired ? 0 : Self.lockedCheckpointCount
        tradingLifecycleArmed = !recoveryRequired
        downstreamRecoveryPending = recoveryRequired
        startupSequencePhase = .idle
        endDashboardRefreshFreeze()
        prepareWarmStartMaterializedState()
        restoreDashboardSnapshotFromCurrentStores()
        if !recoveryRequired {
            rescheduleTimers()
        }
    }

    var dashboardRankedAssets: [Opportunity] {
        isDashboardRefreshInFlight ? frozenRankedAssets : rankedAssets
    }

    var dashboardScannedSignals: [MarketSignal] {
        isDashboardRefreshInFlight ? frozenScannedSignals : scannedSignals
    }

    func beginDashboardRefreshFreezeIfNeeded() {
        guard !isDashboardRefreshInFlight else { return }
        let portfolio = WealthPortfolioStore.shared
        frozenRankedAssets = rankedAssets
        frozenScannedSignals = scannedSignals
        frozenConfirmedHoldings = portfolio.holdings.filter {
            ($0.orderIntent == .live || $0.orderIntent == .sellPending) && $0.orderState != .filled
        }
        frozenPendingHoldings = portfolio.holdings.filter {
            $0.orderIntent == .sellPending && $0.orderState != .filled
        }
        frozenPendingOpportunities = portfolio.activityOpportunities.sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.symbol < rhs.symbol
        }
        frozenCompletedOpportunities = portfolio.completedActivity.filter {
            $0.decisionBias == .avoid || $0.commandText == "SELL COMPLETED"
        }
        stagedDashboardSnapshot = nil
        isDashboardRefreshInFlight = true
    }

    func endDashboardRefreshFreeze() {
        stagedDashboardSnapshot = nil
        frozenRankedAssets = []
        frozenScannedSignals = []
        frozenConfirmedHoldings = []
        frozenPendingHoldings = []
        frozenPendingOpportunities = []
        frozenCompletedOpportunities = []
        isDashboardRefreshInFlight = false
    }

    func aiLiveResult(for opportunity: Opportunity) -> WealthAILiveResult? {
        aiLiveResultsByKey[WealthOpportunityLaneRules.laneKey(opportunity)]
    }

    func noteActivityRefusal(
        symbol: String,
        market: String,
        state: WealthActivityReturnState,
        reason: String,
        timestamp: Date = .now
    ) {
        let key = WealthOpportunityLaneRules.laneKey(symbol: symbol, market: market)
        activityRefusalsByKey[key] = WealthActivityRefusalHandoff(
            key: key,
            symbol: symbol,
            market: market,
            state: state,
            reason: reason,
            timestamp: timestamp
        )
    }

    func clearActivityRefusal(for key: String) {
        activityRefusalsByKey.removeValue(forKey: key)
    }

    func replaceActivityRefusals(with handoffs: [String: WealthActivityRefusalHandoff]) {
        activityRefusalsByKey = handoffs
    }
}
