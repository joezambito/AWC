import SwiftUI

struct MarketRegionBoardSummary: Identifiable {
    let region: String
    let market: String
    let state: MarketSessionState
    let rawCount: Int
    let greenCount: Int
    let blueCount: Int
    let purpleCount: Int
    let redCount: Int
    let greyCount: Int
    let accentTint: Color

    var id: String { region }
}

extension MarketsView {
    func marketGlobalBucketTotals(from summaries: [MarketRegionBoardSummary]) -> [(id: String, title: String, count: Int, tint: Color)] {
        [
            ("green", "GREEN", summaries.reduce(0) { $0 + $1.greenCount }, WealthTheme.green),
            ("blue", "BLUE", summaries.reduce(0) { $0 + $1.blueCount }, WealthTheme.blue),
            ("purple", "PURPLE", summaries.reduce(0) { $0 + $1.purpleCount }, WealthTheme.purple),
            ("red", "RED", summaries.reduce(0) { $0 + $1.redCount }, WealthTheme.red),
            ("grey", "GREY", summaries.reduce(0) { $0 + $1.greyCount }, WealthTheme.grey)
        ]
    }

    var marketGlobalBucketTotals: [(id: String, title: String, count: Int, tint: Color)] {
        marketGlobalBucketTotals(from: marketBoardSummaries)
    }

    var marketRegionRawCounts: [String: Int] {
        var counts: [String: Int] = [:]

        for (region, opportunities) in marketLaneOpportunitiesByRegion {
            counts[region, default: 0] += opportunities.count
        }

        for (region, records) in importedMarketRecordsByRegion {
            counts[region, default: 0] += records.count
        }

        return counts
    }

    var marketBoardSummaries: [MarketRegionBoardSummary] {
        let brokerName = WealthBrokerStore.shared.selectedBroker.name
        let unresolvedRecordsByRegion = importedMarketRecordsByRegion

        var regions = Set(unresolvedRecordsByRegion.keys)
        regions.formUnion(marketLaneOpportunitiesByRegion.keys)

        let summaries = regions.map { region in
            let liveOpportunities = marketLaneOpportunitiesByRegion[region] ?? []
            let leadMarket = liveOpportunities.first?.market
                ?? scopedWorldShareRecordsByRegion[region]?.first?.market
                ?? region
            let state = BrokerSessionClock.state(for: leadMarket, brokerName: brokerName)
            let unresolvedCount = unresolvedRecordsByRegion[region]?.count ?? 0

            return MarketRegionBoardSummary(
                region: region,
                market: leadMarket,
                state: state,
                rawCount: liveOpportunities.count + unresolvedCount,
                greenCount: liveOpportunities.filter { $0.cardSignalTint == WealthTheme.green }.count,
                blueCount: liveOpportunities.filter { $0.cardSignalTint == WealthTheme.blue }.count,
                purpleCount: liveOpportunities.filter { $0.cardSignalTint == WealthTheme.purple }.count,
                redCount: liveOpportunities.filter { $0.cardSignalTint == WealthTheme.red }.count,
                greyCount: unresolvedCount + liveOpportunities.filter { $0.cardSignalTint == WealthTheme.grey }.count,
                accentTint: liveOpportunities.first?.cardSignalTint ?? marketUniverseTintColor(for: leadMarket)
            )
        }
        .sorted { lhs, rhs in
            let leftIndex = preferredRegionOrder.firstIndex(of: lhs.region) ?? .max
            let rightIndex = preferredRegionOrder.firstIndex(of: rhs.region) ?? .max
            return leftIndex == rightIndex ? lhs.region < rhs.region : leftIndex < rightIndex
        }

        return summaries
    }

    func marketRegionEntries(for region: String) -> [MarketUniverseEntry] {
        let brokerName = WealthBrokerStore.shared.selectedBroker.name
        let liveRankByKey = Dictionary(
            uniqueKeysWithValues: marketLaneOpportunities.map {
                (WealthOpportunityLaneRules.laneKey($0), $0.rank)
            }
        )

        let liveEntries = (marketLaneOpportunitiesByRegion[region] ?? [])
            .map { marketFeedEntry(for: $0, brokerName: brokerName) }
        let importedEntries = (importedMarketRecordsByRegion[region] ?? [])
            .map { marketFeedEntry(for: $0, brokerName: brokerName) }

        let entries = (liveEntries + importedEntries).sorted { lhs, rhs in
            let leftKey = WealthOpportunityLaneRules.laneKey(symbol: lhs.symbol, market: lhs.market)
            let rightKey = WealthOpportunityLaneRules.laneKey(symbol: rhs.symbol, market: rhs.market)
            let leftRank = liveRankByKey[leftKey] ?? Int.max
            let rightRank = liveRankByKey[rightKey] ?? Int.max

            if leftRank != rightRank { return leftRank < rightRank }
            if lhs.priceChangePercent != rhs.priceChangePercent { return lhs.priceChangePercent > rhs.priceChangePercent }
            return lhs.symbol < rhs.symbol
        }

        return entries
    }

    var universeByRegion: [(region: String, items: [MarketUniverseEntry])] {
        let liveRankByKey = Dictionary(
            uniqueKeysWithValues: marketLaneOpportunities.map {
                (WealthOpportunityLaneRules.laneKey($0), $0.rank)
            }
        )

        return Dictionary(grouping: marketFeedEntries, by: \.region)
            .map { key, value in
                let sorted = value.sorted { lhs, rhs in
                    let leftKey = WealthOpportunityLaneRules.laneKey(symbol: lhs.symbol, market: lhs.market)
                    let rightKey = WealthOpportunityLaneRules.laneKey(symbol: rhs.symbol, market: rhs.market)
                    let leftRank = liveRankByKey[leftKey] ?? Int.max
                    let rightRank = liveRankByKey[rightKey] ?? Int.max

                    if leftRank != rightRank { return leftRank < rightRank }
                    if lhs.priceChangePercent != rhs.priceChangePercent { return lhs.priceChangePercent > rhs.priceChangePercent }
                    return lhs.symbol < rhs.symbol
                }
                return (region: key, items: sorted)
            }
            .sorted { lhs, rhs in
                let leftIndex = preferredRegionOrder.firstIndex(of: lhs.region) ?? .max
                let rightIndex = preferredRegionOrder.firstIndex(of: rhs.region) ?? .max
                return leftIndex == rightIndex ? lhs.region < rhs.region : leftIndex < rightIndex
            }
    }

    var regionCalendarEntries: [MarketRegionCalendarEntry] {
        let brokerName = WealthBrokerStore.shared.selectedBroker.name

        return universeByRegion.compactMap { group in
            guard let lead = group.items.first else { return nil }
            let state = BrokerSessionClock.state(for: lead.market, brokerName: brokerName)

            return MarketRegionCalendarEntry(
                id: group.region,
                region: group.region,
                market: lead.marketDisplayLabel,
                marketCount: marketRegionRawCounts[group.region] ?? group.items.count,
                state: state,
                nextTradeText: BrokerSessionClock.nextTradingText(for: lead.market, brokerName: brokerName)
            )
        }
    }

    var routingSnapshots: [MarketRoutingSnapshot] {
        let topRegions = universeByRegion.prefix(3).map { group in
            MarketRoutingSnapshot(
                id: "region-\(group.region)",
                label: group.region,
                detail: group.items.first?.statusText ?? "LIVE",
                tint: group.items.first?.tint ?? WealthTheme.cyan
            )
        }

        let topThemes = marketLaneOpportunities.prefix(3).map { opportunity in
            MarketRoutingSnapshot(
                id: "theme-\(opportunity.symbol)",
                label: opportunity.sector.uppercased(),
                detail: "AI \(opportunity.aiScore)",
                tint: opportunity.confidenceTint
            )
        }

        return Array(topRegions + topThemes)
    }
}
