import SwiftUI
import Combine

extension WealthPreparedSnapshotStore {
    func setVisibleMarketRegions(_ regions: Set<String>) {
        setVisibleMarketRegions(regions, quoteStore: .shared)
    }

    func setMarketsPresentationActive(_ isActive: Bool) {
        guard marketsPresentationActive != isActive else { return }
        marketsPresentationActive = isActive
        if !isActive {
            visibleMarketRegions = []
            marketPriceRefreshTask?.cancel()
            marketPriceRefreshTask = nil
            marketSequentialRegionRefreshTask?.cancel()
            marketSequentialRegionRefreshTask = nil
            pendingCoreRefreshTask?.cancel()
            pendingCoreRefreshTask = nil
        }
    }

    func setVisibleMarketRegions(
        _ regions: Set<String>,
        quoteStore: WealthBrokerQuoteStore
    ) {
        let normalizedRegions = Set(marketSignalRowsByRegion.keys).intersection(regions)
        guard normalizedRegions != visibleMarketRegions else { return }
        visibleMarketRegions = normalizedRegions
        syncVisibleQuoteScope(quoteStore: quoteStore)
        refreshVisibleMarketRows(quoteStore: quoteStore)
    }

    private var quoteStoreBrokerName: String {
        WealthBrokerStore.shared.selectedBroker.name
    }

    private var canDriveLiveMarketPresentation: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        marketsPresentationActive
#endif
    }

    private func scheduleMarketPriceRefresh() {
        guard hasPreparedMarkets else { return }
        guard canDriveLiveMarketPresentation else { return }
        marketPriceRefreshTask?.cancel()
        marketPriceRefreshTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.refreshMarketPrices()
        }
    }

    private func refreshMarketPrices() {
        refreshMarketPrices(quoteStore: .shared)
    }

    private func refreshMarketPrices(
        quoteStore: WealthBrokerQuoteStore
    ) {
        guard canDriveLiveMarketPresentation else { return }
        publishPreparedMarketBoardSummaries(brokerName: quoteStoreBrokerName)
        refreshVisibleMarketRows(quoteStore: quoteStore)
    }

    private func publishPreparedMarketBoardSummaries(brokerName: String) {
        marketsBoardSummaries = marketSignalSummarySeeds.map { seed in
            MarketRegionBoardSummary(
                region: seed.region,
                market: seed.market,
                state: BrokerSessionClock.state(for: seed.market, brokerName: brokerName),
                rawCount: seed.rawCount,
                greenCount: seed.greenCount,
                blueCount: seed.blueCount,
                purpleCount: seed.purpleCount,
                redCount: seed.redCount,
                greyCount: seed.greyCount,
                accentTint: seed.accentTint
            )
        }
    }

    private func prunePreparedMarketRows(to validRegions: Set<String>) {
        marketsCompactRowsByRegion = marketsCompactRowsByRegion.filter { validRegions.contains($0.key) }
        visibleMarketRegions = visibleMarketRegions.intersection(validRegions)
    }

    private func scheduleSequentialMarketRegionRefresh(
        availableRegions: [String],
        activeRegions: Set<String>,
        quoteStore: WealthBrokerQuoteStore
    ) {
        marketSequentialRegionRefreshTask?.cancel()
        guard canDriveLiveMarketPresentation else { return }
        let orderedRegions = orderedMarketRefreshRegions(
            availableRegions: availableRegions,
            activeRegions: activeRegions
        )
#if !targetEnvironment(macCatalyst)
        var nextRows = marketsCompactRowsByRegion
        for region in orderedRegions {
            nextRows[region] = preparedMarketEntries(
                for: region,
                brokerName: quoteStoreBrokerName,
                quoteStore: quoteStore
            )
        }
        if nextRows != marketsCompactRowsByRegion {
            marketsCompactRowsByRegion = nextRows
        }
        return
#endif
    }

    private func syncVisibleQuoteScope(quoteStore: WealthBrokerQuoteStore) {
        guard canDriveLiveMarketPresentation else {
            quoteStore.setVisibleQuoteKeys([])
            return
        }
        let visibleQuoteKeys = visibleMarketRegions.reduce(into: Set<WealthBrokerQuoteKey>()) { partial, region in
            let rowSeeds = marketSignalRowsByRegion[region] ?? []
            for seed in rowSeeds {
                partial.insert(WealthBrokerQuoteKey(symbol: seed.symbol, market: seed.market))
            }
        }
        quoteStore.setVisibleQuoteKeys(visibleQuoteKeys)
    }

    private func refreshVisibleMarketRows(
        quoteStore: WealthBrokerQuoteStore
    ) {
        guard canDriveLiveMarketPresentation else { return }
        guard !visibleMarketRegions.isEmpty else { return }
        var nextRows = marketsCompactRowsByRegion
        for region in visibleMarketRegions {
            nextRows[region] = preparedMarketEntries(
                for: region,
                brokerName: quoteStoreBrokerName,
                quoteStore: quoteStore
            )
        }
        guard nextRows != marketsCompactRowsByRegion else { return }
        marketsCompactRowsByRegion = nextRows
    }

    private func orderedMarketRefreshRegions(
        availableRegions: [String],
        activeRegions: Set<String>
    ) -> [String] {
        var regions = Array(Set(availableRegions))
        regions.sort { lhs, rhs in
            let leftPriority = marketRefreshPriority(for: lhs, activeRegions: activeRegions)
            let rightPriority = marketRefreshPriority(for: rhs, activeRegions: activeRegions)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            let leftIndex = PreparedMarketSnapshotSupport.preferredRegionOrder.firstIndex(of: lhs) ?? .max
            let rightIndex = PreparedMarketSnapshotSupport.preferredRegionOrder.firstIndex(of: rhs) ?? .max
            return leftIndex == rightIndex ? lhs < rhs : leftIndex < rightIndex
        }
        return regions
    }

    private func marketRefreshPriority(
        for region: String,
        activeRegions: Set<String>
    ) -> Int {
        if activeRegions.contains(region) {
            return 0
        }
        return 1
    }

    private func preparedMarketEntries(
        for region: String,
        brokerName: String,
        quoteStore: WealthBrokerQuoteStore
    ) -> [MarketUniverseEntry] {
        let seeds = marketSignalRowsByRegion[region] ?? []

        let sortedEntries = seeds.map { seed -> MarketUniverseEntry in
            switch seed {
            case .opportunity(let opportunity):
                return marketFeedEntry(
                    for: opportunity,
                    brokerName: brokerName,
                    quoteStore: quoteStore
                )
            case .record(let record):
                return marketFeedEntry(
                    for: record,
                    brokerName: brokerName,
                    quoteStore: quoteStore,
                    opportunityLookup: marketsOpportunityLookup,
                    opportunitiesBySymbol: marketsOpportunitiesBySymbol
                )
            }
        }
        .sorted {
            let leftKey = WealthOpportunityLaneRules.laneKey(symbol: $0.symbol, market: $0.market)
            let rightKey = WealthOpportunityLaneRules.laneKey(symbol: $1.symbol, market: $1.market)
            let leftRank = marketLiveRankByKey[leftKey] ?? Int.max
            let rightRank = marketLiveRankByKey[rightKey] ?? Int.max

            if leftRank != rightRank { return leftRank < rightRank }
            if $0.priceChangePercent != $1.priceChangePercent { return $0.priceChangePercent > $1.priceChangePercent }
            return $0.symbol < $1.symbol
        }

        return Array(sortedEntries.prefix(100))
    }
}
