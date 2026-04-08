import Foundation

extension WealthEngineStore {
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
