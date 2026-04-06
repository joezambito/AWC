import SwiftUI

extension MarketsView {
    func buildScopedWorldShareRecords() -> [MarketUniverseRecord] {
        universeStore.worldShareRecordsByRegion.values
            .flatMap { $0 }
            .sorted(by: MarketUniverseRecord.browserOrder)
    }

    func buildEnabledRankedAssets() -> [Opportunity] {
        WealthAllCardsStore.shared.currentMarketCards(preferredRefreshTime: engine.lastRefresh)
    }

    func buildImportedMarketRecordsByRegion(
        scopedWorldShareRecordsByRegion: [String: [MarketUniverseRecord]],
        marketLaneOpportunities: [Opportunity],
        marketOpportunityLookup: [String: Opportunity],
        marketOpportunitiesBySymbol: [String: [Opportunity]],
        excludedKeys: Set<String>
    ) -> [String: [MarketUniverseRecord]] {
        let marketByKey = Dictionary(
            uniqueKeysWithValues: marketLaneOpportunities.map { (WealthOpportunityLaneRules.laneKey($0), $0) }
        )

        return scopedWorldShareRecordsByRegion.reduce(into: [String: [MarketUniverseRecord]]()) { partial, item in
            let (region, records) = item
            let filtered = records.filter { record in
                let key = WealthOpportunityLaneRules.laneKey(symbol: record.symbol, market: record.market)
                if marketByKey[key] != nil || excludedKeys.contains(key) {
                    return false
                }

                guard let opportunity = marketOpportunity(
                    for: record,
                    marketOpportunityLookup: marketOpportunityLookup,
                    marketOpportunitiesBySymbol: marketOpportunitiesBySymbol
                ) else {
                    return true
                }

                let opportunityKey = WealthOpportunityLaneRules.laneKey(opportunity)
                return marketByKey[opportunityKey] == nil && !excludedKeys.contains(opportunityKey)
            }
            guard !filtered.isEmpty else { return }
            partial[region] = filtered
        }
    }

    var scopedMarketUniverseRecords: [MarketUniverseRecord] {
        universeStore.records
    }

    var scopedWorldShareRecords: [MarketUniverseRecord] {
        preparedSnapshot.hasPreparedMarkets
            ? preparedSnapshot.marketsScopedWorldShareRecords
            : buildScopedWorldShareRecords()
    }

    var scopedWorldShareRecordsByRegion: [String: [MarketUniverseRecord]] {
        preparedSnapshot.hasPreparedMarkets
            ? preparedSnapshot.marketsScopedWorldShareRecordsByRegion
            : Dictionary(grouping: scopedWorldShareRecords, by: \.regionCode)
    }

    var marketBoardExcludedKeys: Set<String> {
        Set(marketLaneOpportunities.map(WealthOpportunityLaneRules.laneKey))
            .union(laneActivityKeys)
            .union(laneHoldingKeys)
            .union(laneLivePickKeys)
    }

    var quoteableWorldShareRecords: [MarketUniverseRecord] {
        scopedWorldShareRecords
    }

    var lanePortfolio: WealthPortfolioStore {
        WealthPortfolioStore.shared
    }

    var enabledRankedAssets: [Opportunity] {
        preparedSnapshot.hasPreparedMarkets ? preparedSnapshot.marketsEnabledRankedAssets : buildEnabledRankedAssets()
    }

    var marketOpportunityLookup: [String: Opportunity] {
        preparedSnapshot.hasPreparedMarkets
            ? preparedSnapshot.marketsOpportunityLookup
            : Dictionary(
                uniqueKeysWithValues: marketLaneOpportunities.map {
                    (WealthOpportunityLaneRules.laneKey($0), $0)
                }
            )
    }

    var marketOpportunitiesBySymbol: [String: [Opportunity]] {
        preparedSnapshot.hasPreparedMarkets
            ? preparedSnapshot.marketsOpportunitiesBySymbol
            : Dictionary(grouping: marketLaneOpportunities, by: { $0.symbol.uppercased() })
    }

    var marketRecordsBySymbol: [String: [MarketUniverseRecord]] {
        preparedSnapshot.hasPreparedMarkets
            ? preparedSnapshot.marketsRecordsBySymbol
            : Dictionary(grouping: quoteableWorldShareRecords, by: { $0.symbol.uppercased() })
    }

    var laneActivityKeys: Set<String> {
        Set(lanePortfolio.activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
    }

    var laneHoldingKeys: Set<String> {
        Set(
            lanePortfolio.holdings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
    }

    var laneLivePicks: [Opportunity] {
        let marketCards = WealthAllCardsStore.shared.currentMarketCards(preferredRefreshTime: engine.lastRefresh)
        return WealthOpportunityLaneRules.livePicks(
            from: marketCards,
            aiLiveResults: engine.aiLiveResultsByKey,
            activityKeys: laneActivityKeys,
            holdingKeys: laneHoldingKeys,
            spendableCash: lanePortfolio.freeBuyingPower
        )
    }

    var laneLivePickKeys: Set<String> {
        Set(laneLivePicks.map(WealthOpportunityLaneRules.laneKey))
    }

    var marketLaneOpportunities: [Opportunity] {
        preparedSnapshot.hasPreparedMarkets
            ? preparedSnapshot.marketsLaneOpportunities
            : WealthAllCardsStore.shared.currentMarketCards(preferredRefreshTime: engine.lastRefresh)
    }

    var marketLaneOpportunitiesByRegion: [String: [Opportunity]] {
        preparedSnapshot.hasPreparedMarkets
            ? preparedSnapshot.marketsLaneOpportunitiesByRegion
            : Dictionary(grouping: marketLaneOpportunities, by: { WealthMarketLabels.region(for: $0.market) })
    }

    var importedMarketRecords: [MarketUniverseRecord] {
        importedMarketRecordsByRegion.values.flatMap { $0 }
    }

    var importedMarketRecordsByRegion: [String: [MarketUniverseRecord]] {
        preparedSnapshot.hasPreparedMarkets
            ? preparedSnapshot.marketsImportedRecordsByRegion
            : buildImportedMarketRecordsByRegion(
                scopedWorldShareRecordsByRegion: scopedWorldShareRecordsByRegion,
                marketLaneOpportunities: marketLaneOpportunities,
                marketOpportunityLookup: marketOpportunityLookup,
                marketOpportunitiesBySymbol: marketOpportunitiesBySymbol,
                excludedKeys: laneActivityKeys.union(laneHoldingKeys).union(laneLivePickKeys)
            )
    }

    func importedMarketRecords(for region: String) -> [MarketUniverseRecord] {
        importedMarketRecordsByRegion[region] ?? []
    }

    func marketOpportunity(for record: MarketUniverseRecord) -> Opportunity? {
        marketOpportunity(
            for: record,
            marketOpportunityLookup: marketOpportunityLookup,
            marketOpportunitiesBySymbol: marketOpportunitiesBySymbol
        )
    }

    private func marketOpportunity(
        for record: MarketUniverseRecord,
        marketOpportunityLookup: [String: Opportunity],
        marketOpportunitiesBySymbol: [String: [Opportunity]]
    ) -> Opportunity? {
        let exactKey = WealthOpportunityLaneRules.laneKey(symbol: record.symbol, market: record.market)
        if let exact = marketOpportunityLookup[exactKey] {
            return exact
        }

        let candidates = marketOpportunitiesBySymbol[record.symbol.uppercased()] ?? []
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

        let recordRegion = record.regionCode
        let regionMatches = candidates.filter { WealthMarketLabels.region(for: $0.market) == recordRegion }
        if regionMatches.count == 1 {
            return regionMatches[0]
        }

        return nil
    }

    func marketRecord(for opportunity: Opportunity) -> MarketUniverseRecord? {
        let candidates = marketRecordsBySymbol[opportunity.symbol.uppercased()] ?? []
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

    func marketQuote(for opportunity: Opportunity) -> WealthBrokerQuote? {
        if let exact = quoteStore.marketDisplayQuote(symbol: opportunity.symbol, market: opportunity.market) {
            return exact
        }

        guard let record = marketRecord(for: opportunity) else { return nil }
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
}
