import SwiftUI
import Combine

extension WealthPreparedSnapshotStore {
    func refreshCore() {
        refreshCore(engine: .shared, portfolio: .shared)
    }

    func requestCoreRefresh() {
        pendingCoreRefreshTask?.cancel()
        pendingCoreRefreshTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.pendingCoreRefreshTask = nil
            self.refreshCore(engine: .shared, portfolio: .shared)
        }
    }

    func refreshCore(
        engine: WealthEngineStore,
        portfolio: WealthPortfolioStore
    ) {
        let marketCards = WealthAllCardsStore.shared.currentMarketCards(preferredRefreshTime: engine.lastRefresh)
        let activityOpportunities = portfolio.activityOpportunities.sorted(by: activityOpportunitySort)
        let holdingCards = portfolio.holdings
        let completedActivity = portfolio.completedActivity
        let currentSignature = PreparedCoreInputSignature(
            engineLastRefresh: engine.lastRefresh,
            marketCardFingerprint: opportunityFingerprint(marketCards),
            aiLiveResultFingerprint: aiLiveResultFingerprint(engine.aiLiveResultsByKey),
            activityOpportunityFingerprint: opportunityFingerprint(activityOpportunities),
            holdingFingerprint: holdingFingerprint(holdingCards),
            completedActivityFingerprint: opportunityFingerprint(completedActivity),
            spendableCash: portfolio.freeBuyingPower,
            dashboardFreezeActive: engine.isDashboardRefreshInFlight
        )

        if hasPreparedCore, currentSignature == lastCoreInputSignature {
            return
        }

        let holdingLaneKeys = Set(
            holdingCards
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
        let pendingCards = engine.isDashboardRefreshInFlight
        ? engine.frozenPendingOpportunities
        : activityOpportunities
        let activityLaneKeys = Set(pendingCards.map(WealthOpportunityLaneRules.laneKey))
        let livePicks = WealthOpportunityLaneRules.livePicks(
            from: marketCards,
            aiLiveResults: engine.aiLiveResultsByKey,
            activityKeys: activityLaneKeys,
            holdingKeys: holdingLaneKeys,
            spendableCash: portfolio.freeBuyingPower
        )
        let sortedLivePicks = livePicks.sorted(by: preparedRankOrdering)
        let pendingHoldings = engine.isDashboardRefreshInFlight
        ? engine.frozenPendingHoldings
        : holdingCards.filter { $0.orderIntent == .sellPending && $0.orderState != .filled }
        let sortedPendingHoldings = pendingHoldings.sorted {
            if $0.aiScore != $1.aiScore { return $0.aiScore < $1.aiScore }
            return $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending
        }
        let completedCards = engine.isDashboardRefreshInFlight
        ? engine.frozenCompletedOpportunities
        : completedActivity.filter {
            $0.decisionBias == .avoid || $0.commandText == "SELL COMPLETED"
        }
        let sortedCompletedCards = completedCards.sorted(by: preparedRankOrdering)

        aiLiveCards = sortedLivePicks
        activityPendingCards = pendingCards.sorted(by: preparedRankOrdering)
        activityPendingHoldings = sortedPendingHoldings
        activityCompletedCards = sortedCompletedCards
        lastCoreInputSignature = currentSignature
        hasPreparedCore = true
    }

    func refreshMarkets(universeStore: WealthMarketUniverseStore) {
        refreshMarkets(
            engine: .shared,
            portfolio: .shared,
            universeStore: universeStore,
            quoteStore: .shared
        )
    }

    func invalidatePreparedMarkets() {
        hasPreparedMarkets = false
        lastMarketSignalInputSignature = nil
    }

    func refreshMarkets(
        engine: WealthEngineStore,
        portfolio: WealthPortfolioStore,
        universeStore: WealthMarketUniverseStore,
        quoteStore: WealthBrokerQuoteStore
    ) {
        let marketCards = WealthAllCardsStore.shared.currentMarketCards(preferredRefreshTime: engine.lastRefresh)
        let pendingHoldings = portfolio.holdings.filter { $0.orderState != .filled }
        let activityOpportunities = portfolio.activityOpportunities
        let currentSignature = PreparedMarketSignalInputSignature(
            engineLastRefresh: engine.lastRefresh,
            marketCardFingerprint: opportunityFingerprint(marketCards),
            aiLiveResultFingerprint: aiLiveResultFingerprint(engine.aiLiveResultsByKey),
            activityOpportunityFingerprint: opportunityFingerprint(activityOpportunities),
            pendingHoldingFingerprint: holdingFingerprint(pendingHoldings),
            universeRecordCount: universeStore.records.count,
            universeLastSuccessfulLoadAt: universeStore.lastSuccessfulLoadAt
        )

        if hasPreparedMarkets, currentSignature == lastMarketSignalInputSignature {
            return
        }

        let worldShareRecords = universeStore.worldShareRecordsByRegion.values
            .flatMap { $0 }
            .sorted(by: MarketUniverseRecord.browserOrder)
        let worldShareRecordsByRegion = Dictionary(grouping: worldShareRecords, by: \.regionCode)
        let recordsBySymbol = Dictionary(grouping: worldShareRecords, by: { $0.symbol.uppercased() })
        let activityKeys = Set(activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
        let holdingKeys = Set(
            pendingHoldings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
        let livePicks = WealthOpportunityLaneRules.livePicks(
            from: marketCards,
            aiLiveResults: engine.aiLiveResultsByKey,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            spendableCash: portfolio.freeBuyingPower
        )
        let livePickKeys = Set(livePicks.map(WealthOpportunityLaneRules.laneKey))
        let laneOpportunities = marketCards.sorted(by: preparedRankOrdering)
        WealthPipelineTraceLogger.log(stage: "prepared_market_lane", opportunities: laneOpportunities)
        let opportunityLookup = Dictionary(
            uniqueKeysWithValues: laneOpportunities.map {
                (WealthOpportunityLaneRules.laneKey($0), $0)
            }
        )
        let opportunitiesBySymbol = Dictionary(grouping: laneOpportunities, by: { $0.symbol.uppercased() })
        let laneOpportunitiesByRegion = Dictionary(
            grouping: laneOpportunities,
            by: { WealthMarketLabels.region(for: $0.market) }
        )
        let excludedKeys = activityKeys.union(holdingKeys).union(livePickKeys)
        let laneByKey = Dictionary(
            uniqueKeysWithValues: laneOpportunities.map { (WealthOpportunityLaneRules.laneKey($0), $0) }
        )

        let importedRecordsByRegion = worldShareRecordsByRegion.reduce(into: [String: [MarketUniverseRecord]]()) { partial, item in
            let (region, records) = item
            let filtered = records.filter { record in
                let key = WealthOpportunityLaneRules.laneKey(symbol: record.symbol, market: record.market)
                if laneByKey[key] != nil || excludedKeys.contains(key) {
                    return false
                }

                guard let opportunity = marketOpportunity(
                    for: record,
                    opportunityLookup: opportunityLookup,
                    opportunitiesBySymbol: opportunitiesBySymbol
                ) else {
                    return true
                }

                let opportunityKey = WealthOpportunityLaneRules.laneKey(opportunity)
                return laneByKey[opportunityKey] == nil && !excludedKeys.contains(opportunityKey)
            }
            guard !filtered.isEmpty else { return }
            partial[region] = filtered
        }

        let liveRankByKey = Dictionary(
            uniqueKeysWithValues: laneOpportunities.map {
                (WealthOpportunityLaneRules.laneKey($0), max($0.rank, 1))
            }
        )
        let boardRegions = Set(importedRecordsByRegion.keys).union(laneOpportunitiesByRegion.keys)
        let boardSummaries = boardRegions.map { region in
            let liveOpportunities = laneOpportunitiesByRegion[region] ?? []
            let leadMarket = liveOpportunities.first?.market
            ?? worldShareRecordsByRegion[region]?.first?.market
            ?? region
            let unresolvedCount = importedRecordsByRegion[region]?.count ?? 0

            return PreparedMarketSignalSummarySeed(
                region: region,
                market: leadMarket,
                rawCount: liveOpportunities.count + unresolvedCount,
                greenCount: liveOpportunities.filter { $0.cardSignalTint == WealthTheme.green }.count,
                blueCount: liveOpportunities.filter { $0.cardSignalTint == WealthTheme.blue }.count,
                purpleCount: liveOpportunities.filter { $0.cardSignalTint == WealthTheme.purple }.count,
                redCount: liveOpportunities.filter { $0.cardSignalTint == WealthTheme.red }.count,
                greyCount: unresolvedCount + liveOpportunities.filter { $0.cardSignalTint == WealthTheme.grey }.count,
                accentTint: liveOpportunities.first?.cardSignalTint ?? marketUniverseTintColor(for: leadMarket)
            )
        }
        .sorted { (lhs: PreparedMarketSignalSummarySeed, rhs: PreparedMarketSignalSummarySeed) in
            let leftIndex = PreparedMarketSnapshotSupport.preferredRegionOrder.firstIndex(of: lhs.region) ?? .max
            let rightIndex = PreparedMarketSnapshotSupport.preferredRegionOrder.firstIndex(of: rhs.region) ?? .max
            return leftIndex == rightIndex ? lhs.region < rhs.region : leftIndex < rightIndex
        }

        let compactRowsByRegion = boardSummaries.reduce(into: [String: [PreparedMarketSignalRowSeed]]()) { partialResult, summary in
            let region = summary.region
            guard partialResult[region] == nil else { return }
            let liveRows = (laneOpportunitiesByRegion[region] ?? []).map(PreparedMarketSignalRowSeed.opportunity)
            let importedRows = (importedRecordsByRegion[region] ?? []).map(PreparedMarketSignalRowSeed.record)
            partialResult[region] = liveRows + importedRows
        }

        marketsScopedWorldShareRecords = worldShareRecords
        marketsScopedWorldShareRecordsByRegion = worldShareRecordsByRegion
        marketsEnabledRankedAssets = laneOpportunities
        marketsOpportunityLookup = opportunityLookup
        marketsOpportunitiesBySymbol = opportunitiesBySymbol
        marketsRecordsBySymbol = recordsBySymbol
        marketsLaneOpportunities = laneOpportunities
        marketsLaneOpportunitiesByRegion = laneOpportunitiesByRegion
        marketsImportedRecordsByRegion = importedRecordsByRegion
        marketSignalSummarySeeds = boardSummaries
        marketSignalRowsByRegion = compactRowsByRegion
        marketLiveRankByKey = liveRankByKey
        lastMarketSignalInputSignature = currentSignature
        let activeRegions = engine.activeExecutionRegionLabels()
        publishPreparedMarketBoardSummaries(brokerName: quoteStoreBrokerName)
        prunePreparedMarketRows(to: Set(boardSummaries.map(\.region)))
        syncVisibleQuoteScope(quoteStore: quoteStore)
        scheduleSequentialMarketRegionRefresh(
            availableRegions: boardSummaries.map(\.region),
            activeRegions: activeRegions,
            quoteStore: quoteStore
        )
        hasPreparedMarkets = true
    }
}
