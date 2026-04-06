import SwiftUI
import Combine

private struct PreparedMarketSignalSummarySeed {
    let region: String
    let market: String
    let rawCount: Int
    let greenCount: Int
    let blueCount: Int
    let purpleCount: Int
    let redCount: Int
    let greyCount: Int
    let accentTint: Color
}

private enum PreparedMarketSignalRowSeed {
    case opportunity(Opportunity)
    case record(MarketUniverseRecord)

    var id: String {
        switch self {
        case .opportunity(let opportunity):
            return "\(opportunity.symbol)-\(opportunity.market)"
        case .record(let record):
            return record.id
        }
    }

    var symbol: String {
        switch self {
        case .opportunity(let opportunity):
            return opportunity.symbol
        case .record(let record):
            return record.symbol
        }
    }

    var market: String {
        switch self {
        case .opportunity(let opportunity):
            return opportunity.market
        case .record(let record):
            return record.market
        }
    }
}

private struct PreparedMarketSignalInputSignature: Equatable {
    let engineLastRefresh: Date?
    let marketCardFingerprint: String
    let aiLiveResultFingerprint: String
    let activityOpportunityFingerprint: String
    let pendingHoldingFingerprint: String
    let universeRecordCount: Int
    let universeLastSuccessfulLoadAt: Date?
}

private struct PreparedCoreInputSignature: Equatable {
    let engineLastRefresh: Date?
    let marketCardFingerprint: String
    let aiLiveResultFingerprint: String
    let activityOpportunityFingerprint: String
    let holdingFingerprint: String
    let completedActivityFingerprint: String
    let spendableCash: Double
    let dashboardFreezeActive: Bool
}

private enum PreparedMarketSnapshotSupport {
    static let preferredRegionOrder = ["US", "CA", "EU", "APAC", "ME", "LATAM", "AFRICA", "AU", "FX", "CRYPTO", "GLOBAL", "UNKNOWN"]

    static func marketPriceText(price: Double, hasQuoteData: Bool) -> String {
        if hasQuoteData {
            return WealthFormat.money(price)
        }
        return marketQuotePendingDisplayText
    }
}

@MainActor
final class WealthPreparedSnapshotStore: ObservableObject {
    static let shared = WealthPreparedSnapshotStore()

    @Published private(set) var hasPreparedCore = false
    @Published private(set) var hasPreparedMarkets = false
    @Published private(set) var marketsBoardSummaries: [MarketRegionBoardSummary] = []
    @Published private(set) var marketsCompactRowsByRegion: [String: [MarketUniverseEntry]] = [:]
    @Published private(set) var aiLiveCards: [Opportunity] = []
    @Published private(set) var activityPendingCards: [Opportunity] = []
    @Published private(set) var activityPendingHoldings: [Holding] = []
    @Published private(set) var activityCompletedCards: [Opportunity] = []

    private(set) var marketsScopedWorldShareRecords: [MarketUniverseRecord] = []
    private(set) var marketsScopedWorldShareRecordsByRegion: [String: [MarketUniverseRecord]] = [:]
    private(set) var marketsEnabledRankedAssets: [Opportunity] = []
    private(set) var marketsOpportunityLookup: [String: Opportunity] = [:]
    private(set) var marketsOpportunitiesBySymbol: [String: [Opportunity]] = [:]
    private(set) var marketsRecordsBySymbol: [String: [MarketUniverseRecord]] = [:]
    private(set) var marketsLaneOpportunities: [Opportunity] = []
    private(set) var marketsLaneOpportunitiesByRegion: [String: [Opportunity]] = [:]
    private(set) var marketsImportedRecordsByRegion: [String: [MarketUniverseRecord]] = [:]
    private var marketSignalSummarySeeds: [PreparedMarketSignalSummarySeed] = []
    private var marketSignalRowsByRegion: [String: [PreparedMarketSignalRowSeed]] = [:]
    private var marketLiveRankByKey: [String: Int] = [:]
    private var lastCoreInputSignature: PreparedCoreInputSignature?
    private var lastMarketSignalInputSignature: PreparedMarketSignalInputSignature?
    private var visibleMarketRegions: Set<String> = []
    private var cancellables: Set<AnyCancellable> = []
    private var marketPriceRefreshTask: Task<Void, Never>?
    private var marketSequentialRegionRefreshTask: Task<Void, Never>?
    private var pendingCoreRefreshTask: Task<Void, Never>?
    private var marketsPresentationActive = false

    private init() {
        WealthBrokerQuoteStore.shared.$displayQuotes
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleMarketPriceRefresh()
            }
            .store(in: &cancellables)
    }

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

    private func marketOpportunity(
        for record: MarketUniverseRecord,
        opportunityLookup: [String: Opportunity],
        opportunitiesBySymbol: [String: [Opportunity]]
    ) -> Opportunity? {
        let exactKey = WealthOpportunityLaneRules.laneKey(symbol: record.symbol, market: record.market)
        if let exact = opportunityLookup[exactKey] {
            return exact
        }

        let candidates = opportunitiesBySymbol[record.symbol.uppercased()] ?? []
        guard !candidates.isEmpty else { return nil }

        let canonicalRecordMarket = canonicalComparableMarket(
            market: record.market,
            assetType: record.assetType
        )
        let canonicalMatches = candidates.filter {
            canonicalComparableMarket(market: $0.market) == canonicalRecordMarket
        }
        if canonicalMatches.count == 1 {
            return canonicalMatches[0]
        }

        if candidates.count == 1 {
            return candidates[0]
        }

        let regionMatches = candidates.filter { WealthMarketLabels.region(for: $0.market) == record.regionCode }
        if regionMatches.count == 1 {
            return regionMatches[0]
        }

        return nil
    }

    private func marketRecord(
        for opportunity: Opportunity,
        recordsBySymbol: [String: [MarketUniverseRecord]]
    ) -> MarketUniverseRecord? {
        let candidates = recordsBySymbol[opportunity.symbol.uppercased()] ?? []
        guard !candidates.isEmpty else { return nil }

        if let exact = candidates.first(where: { $0.market == opportunity.market }) {
            return exact
        }

        let canonicalOpportunityMarket = canonicalComparableMarket(market: opportunity.market)
        let canonicalMatches = candidates.filter {
            canonicalComparableMarket(market: $0.market, assetType: $0.assetType) == canonicalOpportunityMarket
        }
        if canonicalMatches.count == 1 {
            return canonicalMatches[0]
        }

        let opportunityRegion = WealthMarketLabels.region(for: opportunity.market)
        let regionMatches = candidates.filter { $0.regionCode == opportunityRegion }
        if regionMatches.count == 1 {
            return regionMatches[0]
        }

        if candidates.count == 1 {
            return candidates[0]
        }

        return nil
    }

    private func marketFeedEntry(
        for opportunity: Opportunity,
        brokerName: String,
        quoteStore: WealthBrokerQuoteStore
    ) -> MarketUniverseEntry {
        let brokerQuote = marketQuote(
            for: opportunity,
            quoteStore: quoteStore,
            recordsBySymbol: marketsRecordsBySymbol
        )
        let displayPrice = brokerQuote?.price ?? opportunity.price
        let displayChangePercent = brokerQuote?.changePercent ?? opportunity.priceChangePercent
        let hasQuoteData = brokerQuote != nil
        let isDelayed = brokerQuote?.isDelayed == true
        let isStale = brokerQuote.map { Date().timeIntervalSince($0.timestamp) > 75 } ?? true
        let hasFreshData = brokerQuote != nil && !isStale
        let marketTint = opportunity.cardSignalTint
        let priceText = brokerQuote.map { WealthFormat.money($0.price) } ?? PreparedMarketSnapshotSupport.marketPriceText(price: opportunity.price, hasQuoteData: false)
        let changeText = brokerQuote.map {
            $0.changePercent >= 0 ? "+\(WealthFormat.percent($0.changePercent))" : WealthFormat.percent($0.changePercent)
        } ?? (opportunity.priceChangePercent >= 0 ? "+\(WealthFormat.percent(opportunity.priceChangePercent))" : WealthFormat.percent(opportunity.priceChangePercent))
        let statusText = brokerQuote == nil ? marketQuotePendingDisplayText : (isDelayed ? "DELAYED" : "LIVE")

        return MarketUniverseEntry(
            id: "\(opportunity.symbol)-\(opportunity.market)",
            symbol: opportunity.symbol,
            market: opportunity.market,
            marketDisplayLabel: WealthMarketLabels.display(for: opportunity.market),
            region: WealthMarketLabels.region(for: opportunity.market),
            sector: opportunity.sector,
            price: displayPrice,
            priceChangePercent: displayChangePercent,
            hasQuoteData: hasQuoteData,
            isDelayed: isDelayed,
            priceText: priceText,
            aiScoreText: "\(opportunity.marketQualityTier.displayLabel) · #\(max(opportunity.rank, 1))",
            changeText: changeText,
            confidenceText: "AI \(opportunity.aiScore) • CONF \(opportunity.confidence)%",
            backingOpportunityKey: WealthOpportunityLaneRules.laneKey(opportunity),
            statusText: statusText,
            dataAgeText: brokerQuote.map { WealthFormat.age($0.timestamp) } ?? opportunity.sourceAgeText,
            nextTradeText: BrokerSessionClock.nextTradingText(for: opportunity.market, brokerName: brokerName),
            whyText: opportunity.reviewSummary,
            tint: marketTint,
            backgroundTint: marketTint,
            borderTint: marketTint,
            hasFreshData: hasFreshData,
            aiLabelBand: marketLabelBand(for: opportunity),
            shieldExitPrice: opportunity.shieldExitPrice,
            surgeExitPrice: opportunity.surgeExitPrice,
            shieldTriggerPercent: opportunity.shieldTriggerPercent,
            surgeTriggerPercent: opportunity.surgeTriggerPercent,
            hasBackingOpportunity: true
        )
    }

    private func marketFeedEntry(
        for record: MarketUniverseRecord,
        brokerName: String,
        quoteStore: WealthBrokerQuoteStore,
        opportunityLookup: [String: Opportunity],
        opportunitiesBySymbol: [String: [Opportunity]]
    ) -> MarketUniverseEntry {
        let opportunity = marketOpportunity(
            for: record,
            opportunityLookup: opportunityLookup,
            opportunitiesBySymbol: opportunitiesBySymbol
        )
        let resolution = WealthIBKRInstrumentResolver.resolution(for: record)
        let brokerQuote = quoteStore.marketDisplayQuote(symbol: record.symbol, market: record.market)
        let hasQuoteData = brokerQuote != nil
        let price = brokerQuote?.price ?? 0
        let changePercent = brokerQuote?.changePercent ?? 0
        let isDelayed = brokerQuote?.isDelayed == true
        let isStale = brokerQuote.map { Date().timeIntervalSince($0.timestamp) > 75 } ?? true
        let hasFreshData = brokerQuote != nil && !isStale
        let hasResolvedAI = opportunity != nil
        let accentTint = opportunity?.cardSignalTint ?? WealthTheme.grey
        let marketTint = hasResolvedAI ? accentTint : WealthTheme.grey
        let quoteAgeText = brokerQuote.map { WealthFormat.age($0.timestamp) } ?? (resolution.isSupportedEquity ? marketQuotePendingAgeDisplayText : resolution.uiLabel)
        let priceText = brokerQuote.map { WealthFormat.money($0.price) } ?? PreparedMarketSnapshotSupport.marketPriceText(price: price, hasQuoteData: false)
        let changeText = brokerQuote.map {
            $0.changePercent >= 0 ? "+\(WealthFormat.percent($0.changePercent))" : WealthFormat.percent($0.changePercent)
        } ?? marketQuotePendingChangeDisplayText
        let statusText: String
        if !resolution.isSupportedEquity {
            statusText = resolution.uiLabel.uppercased()
        } else if brokerQuote == nil {
            statusText = marketQuotePendingDisplayText
        } else {
            statusText = isDelayed ? "DELAYED" : "LIVE"
        }
        let whyText = brokerQuote == nil
        ? resolution.reason
        : (record.companyName?.isEmpty == false ? record.companyName! : "\(record.assetTypeDisplay) instrument")
        let marketDisplay = resolution.resolvedExchange ?? record.marketDisplayLabel

        return MarketUniverseEntry(
            id: record.id,
            symbol: record.symbol,
            market: record.market,
            marketDisplayLabel: marketDisplay,
            region: record.regionCode,
            sector: record.assetTypeDisplay,
            price: price,
            priceChangePercent: changePercent,
            hasQuoteData: hasQuoteData,
            isDelayed: isDelayed,
            priceText: priceText,
            aiScoreText: opportunity.map { "\($0.marketQualityTier.displayLabel) · #\(max($0.rank, 1))" } ?? "RANK --",
            changeText: changeText,
            confidenceText: opportunity.map { "AI \($0.aiScore) • CONF \($0.confidence)%" } ?? "AI --",
            backingOpportunityKey: opportunity.map(WealthOpportunityLaneRules.laneKey),
            statusText: statusText,
            dataAgeText: quoteAgeText,
            nextTradeText: BrokerSessionClock.nextTradingText(for: record.market, brokerName: brokerName),
            whyText: whyText,
            tint: marketTint,
            backgroundTint: marketTint,
            borderTint: marketTint,
            hasFreshData: hasFreshData,
            aiLabelBand: opportunity.map(marketLabelBand(for:)),
            shieldExitPrice: opportunity?.shieldExitPrice,
            surgeExitPrice: opportunity?.surgeExitPrice,
            shieldTriggerPercent: opportunity?.shieldTriggerPercent,
            surgeTriggerPercent: opportunity?.surgeTriggerPercent,
            hasBackingOpportunity: hasResolvedAI
        )
    }

    private func marketQuote(
        for opportunity: Opportunity,
        quoteStore: WealthBrokerQuoteStore,
        recordsBySymbol: [String: [MarketUniverseRecord]]
    ) -> WealthBrokerQuote? {
        if let exact = quoteStore.marketDisplayQuote(symbol: opportunity.symbol, market: opportunity.market) {
            return exact
        }

        guard let record = marketRecord(for: opportunity, recordsBySymbol: recordsBySymbol) else { return nil }
        return quoteStore.marketDisplayQuote(symbol: record.symbol, market: record.market)
    }

    private func canonicalComparableMarket(
        market: String,
        assetType: String = ""
    ) -> String {
        let market = market.uppercased()
        let assetType = assetType.lowercased()

        if assetType.contains("currenc") { return "FX" }
        if assetType.contains("crypto") { return "CRYPTO" }
        if assetType.contains("bond") && market == "GLOBAL" { return "BOND" }
        if market == "GLOBAL" && (assetType.contains("index") || assetType.contains("fund")) { return "ETF" }

        switch market {
        case "FX":
            return "FX"
        case "CRYPTO":
            return "CRYPTO"
        case "ETF", "REIT", "ADR", "FUND":
            return "ETF"
        case "BOND":
            return "BOND"
        default:
            return market
        }
    }

    private func activityOpportunitySort(_ lhs: Opportunity, _ rhs: Opportunity) -> Bool {
        preparedRankOrdering(lhs, rhs)
    }

    private func preparedRankOrdering(_ lhs: Opportunity, _ rhs: Opportunity) -> Bool {
        let leftTier = lhs.marketQualityTier.rawValue
        let rightTier = rhs.marketQualityTier.rawValue
        if leftTier != rightTier { return leftTier < rightTier }

        let leftRank = max(lhs.rank, 1)
        let rightRank = max(rhs.rank, 1)
        if leftRank != rightRank { return leftRank < rightRank }
        return lhs.symbol.localizedStandardCompare(rhs.symbol) == .orderedAscending
    }

    private func opportunityFingerprint(_ opportunities: [Opportunity]) -> String {
        opportunities
        .sorted { lhs, rhs in
            if lhs.id != rhs.id { return lhs.id < rhs.id }
            return lhs.lastRefreshTimestamp < rhs.lastRefreshTimestamp
        }
        .map {
            [
                $0.id,
                String($0.rank),
                String(describing: $0.orderState.rawValue),
                String(describing: $0.cardHoldingBucket.rawValue),
                String($0.lastRefreshTimestamp.timeIntervalSinceReferenceDate)
            ].joined(separator: "|")
        }
        .joined(separator: "||")
    }

    private func holdingFingerprint(_ holdings: [Holding]) -> String {
        holdings
        .sorted { lhs, rhs in
            if lhs.id != rhs.id { return lhs.id < rhs.id }
            return lhs.lastRefreshTimestamp < rhs.lastRefreshTimestamp
        }
        .map {
            [
                $0.id,
                String(describing: $0.orderIntent.rawValue),
                String(describing: $0.orderState.rawValue),
                String($0.lastRefreshTimestamp.timeIntervalSinceReferenceDate)
            ].joined(separator: "|")
        }
        .joined(separator: "||")
    }

    private func aiLiveResultFingerprint(_ results: [String: WealthAILiveResult]) -> String {
        results.keys.sorted().map { key -> String in
            guard let result = results[key] else { return key }
            return [
                key,
                String(describing: result.aiLiveDecision.rawValue),
                result.reason,
                result.activityReturnState.map { String(describing: $0.rawValue) } ?? "",
                result.activityReturnReason ?? ""
            ].joined(separator: "|")
        }
        .joined(separator: "||")
    }
}
