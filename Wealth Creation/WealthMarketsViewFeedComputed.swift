import SwiftUI

extension MarketsView {
    private var phoneRegionBatchSizeByRegion: [String: Int] {
        [
            "US": 160,
            "AU": 90,
            "CA": 90,
            "EU": 140,
            "APAC": 140,
            "ME": 80,
            "LATAM": 80,
            "AFRICA": 70,
            "GLOBAL": 80,
            "UNKNOWN": 60
        ]
    }

    var quoteableWorldShareRecords: [MarketUniverseRecord] {
        universeStore.worldShareRecords
    }

    private var lanePortfolio: WealthPortfolioStore {
        WealthPortfolioStore.shared
    }

    private var enabledRankedAssets: [Opportunity] {
        let enabledMarkets = engine.activeExecutionMarkets()
        return engine.rankedAssets.filter { enabledMarkets.contains($0.market) }
    }

    private var laneActivityKeys: Set<String> {
        Set(lanePortfolio.activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
    }

    private var laneHoldingKeys: Set<String> {
        Set(
            lanePortfolio.holdings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
    }

    private var laneLivePicks: [Opportunity] {
        WealthOpportunityLaneRules.livePicks(
            from: enabledRankedAssets,
            activityKeys: laneActivityKeys,
            holdingKeys: laneHoldingKeys,
            spendableCash: lanePortfolio.freeBuyingPower
        )
    }

    private var laneLivePickKeys: Set<String> {
        Set(laneLivePicks.map(WealthOpportunityLaneRules.laneKey))
    }

    private var marketLaneOpportunities: [Opportunity] {
        WealthOpportunityLaneRules.marketLane(
            from: enabledRankedAssets,
            activityKeys: laneActivityKeys,
            holdingKeys: laneHoldingKeys,
            livePickKeys: laneLivePickKeys
        )
    }

    var importedMarketRecords: [MarketUniverseRecord] {
        importedMarketRecordsByRegion.values.flatMap { $0 }
    }

    private var importedMarketRecordsByRegion: [String: [MarketUniverseRecord]] {
        let excludedKeys = laneActivityKeys.union(laneHoldingKeys).union(laneLivePickKeys)
        let marketByKey = Dictionary(
            uniqueKeysWithValues: marketLaneOpportunities.map { (WealthOpportunityLaneRules.laneKey($0), $0) }
        )

        return universeStore.worldShareRecordsByRegion.reduce(into: [String: [MarketUniverseRecord]]()) { partial, item in
            let (region, records) = item
            let filtered = records.filter { record in
                let key = WealthOpportunityLaneRules.laneKey(symbol: record.symbol, market: record.market)
                return marketByKey[key] == nil && !excludedKeys.contains(key)
            }
            guard !filtered.isEmpty else { return }
            partial[region] = filtered
        }
    }

    var importedMarketRecordsForCurrentBatch: [MarketUniverseRecord] {
        guard !hasDesktopLayout else { return importedMarketRecords }
        return batchedPhoneImportedMarketRecords()
    }

    private func batchedPhoneImportedMarketRecords() -> [MarketUniverseRecord] {
        var batchedRecords: [MarketUniverseRecord] = []
        let recordsByRegion = importedMarketRecordsByRegion

        for region in preferredRegionOrder {
            let regionRecords = (recordsByRegion[region] ?? [])
                .sorted { lhs, rhs in
                    MarketUniverseRecord.browserOrder(lhs: lhs, rhs: rhs)
                }

            guard !regionRecords.isEmpty else { continue }

            let batchSize = phoneRegionBatchSizeByRegion[region] ?? 60
            let batchCount = max(1, Int(ceil(Double(regionRecords.count) / Double(batchSize))))
            let batchIndex = marketFeedScanBatchIndex % batchCount
            let start = batchIndex * batchSize
            let end = min(start + batchSize, regionRecords.count)

            guard start < end else { continue }
            batchedRecords.append(contentsOf: regionRecords[start..<end])
        }

        for (region, regionRecords) in recordsByRegion where !preferredRegionOrder.contains(region) {
            let sortedRecords = regionRecords.sorted { lhs, rhs in
                MarketUniverseRecord.browserOrder(lhs: lhs, rhs: rhs)
            }
            let batchSize = phoneRegionBatchSizeByRegion[region] ?? 60
            let batchCount = max(1, Int(ceil(Double(sortedRecords.count) / Double(batchSize))))
            let batchIndex = marketFeedScanBatchIndex % batchCount
            let start = batchIndex * batchSize
            let end = min(start + batchSize, sortedRecords.count)

            guard start < end else { continue }
            batchedRecords.append(contentsOf: sortedRecords[start..<end])
        }

        return batchedRecords
    }

    var marketRegionRawCounts: [String: Int] {
        var counts: [String: Int] = [:]

        for opportunity in marketLaneOpportunities {
            let region = WealthMarketLabels.region(for: opportunity.market)
            counts[region, default: 0] += 1
        }

        for record in importedMarketRecords {
            counts[record.regionCode, default: 0] += 1
        }

        return counts
    }

    var marketFeedEntries: [MarketUniverseEntry] {
        let brokerName = WealthBrokerStore.shared.selectedBroker.name

        let liveEntries: [MarketUniverseEntry] = marketLaneOpportunities.compactMap { opportunity in
            let brokerQuote = quoteStore.marketDisplayQuote(symbol: opportunity.symbol, market: opportunity.market)
            let displayPrice = brokerQuote?.price ?? opportunity.price
            let displayChangePercent = brokerQuote?.changePercent ?? opportunity.priceChangePercent
            let hasQuoteData = brokerQuote != nil
            let isDelayed = brokerQuote?.isDelayed == true
            let priceText = brokerQuote.map { WealthFormat.money($0.price) } ?? marketPriceText(price: opportunity.price, hasQuoteData: false)
            let changeText = brokerQuote.map {
                $0.changePercent >= 0 ? "+\(WealthFormat.percent($0.changePercent))" : WealthFormat.percent($0.changePercent)
            } ?? (opportunity.priceChangePercent >= 0 ? "+\(WealthFormat.percent(opportunity.priceChangePercent))" : WealthFormat.percent(opportunity.priceChangePercent))
            let statusText: String
            if brokerQuote == nil {
                statusText = "AI \(opportunity.aiScore) NO DATA"
            } else if isDelayed {
                statusText = "AI \(opportunity.aiScore) DELAYED"
            } else {
                statusText = "AI \(opportunity.aiScore) LIVE"
            }

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
                changeText: changeText,
                confidenceText: "CONF \(opportunity.confidence)%",
                statusText: statusText,
                dataAgeText: brokerQuote.map { WealthFormat.age($0.timestamp) } ?? opportunity.sourceAgeText,
                nextTradeText: BrokerSessionClock.nextTradingText(for: opportunity.market, brokerName: brokerName),
                whyText: opportunity.reviewSummary,
                tint: brokerQuote == nil ? opportunity.confidenceTint : (isDelayed ? WealthTheme.orange : WealthTheme.cyan),
                aiLabelBand: marketLabelBand(for: opportunity),
                shieldExitPrice: opportunity.shieldExitPrice,
                surgeExitPrice: opportunity.surgeExitPrice,
                shieldTriggerPercent: opportunity.shieldTriggerPercent,
                surgeTriggerPercent: opportunity.surgeTriggerPercent
            )
        }

        let importedEntries = importedMarketRecordsForCurrentBatch
            .map { record in
                let resolution = WealthIBKRInstrumentResolver.resolution(for: record)
                let brokerQuote = quoteStore.marketDisplayQuote(symbol: record.symbol, market: record.market)
                let hasQuoteData = brokerQuote != nil
                let price = brokerQuote?.price ?? 0
                let changePercent = brokerQuote?.changePercent ?? 0
                let isDelayed = brokerQuote?.isDelayed == true
                let quoteAgeText = brokerQuote.map { WealthFormat.age($0.timestamp) } ?? (resolution.isSupportedEquity ? "No ticks" : resolution.uiLabel)
                let tint = brokerQuote == nil
                    ? importedEntryTint(resolution: resolution, market: record.market)
                    : (isDelayed ? WealthTheme.orange : WealthTheme.cyan)
                let priceText = brokerQuote.map { WealthFormat.money($0.price) } ?? marketPriceText(price: price, hasQuoteData: false)
                let changeText = brokerQuote.map {
                    $0.changePercent >= 0 ? "+\(WealthFormat.percent($0.changePercent))" : WealthFormat.percent($0.changePercent)
                } ?? "No Data"
                let statusText = brokerQuote == nil ? resolution.uiLabel.uppercased() : (isDelayed ? "DELAYED" : "LIVE")
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
                    changeText: changeText,
                    confidenceText: record.assetTypeDisplay,
                    statusText: statusText,
                    dataAgeText: quoteAgeText,
                    nextTradeText: BrokerSessionClock.nextTradingText(for: record.market, brokerName: brokerName),
                    whyText: whyText,
                    tint: tint,
                    aiLabelBand: nil,
                    shieldExitPrice: nil,
                    surgeExitPrice: nil,
                    shieldTriggerPercent: nil,
                    surgeTriggerPercent: nil
                )
            }

        return liveEntries + importedEntries
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

private func marketLabelBand(for opportunity: Opportunity) -> MarketUniverseLabelBand {
    let signalTint = opportunity.cardSignalTint
    if signalTint == WealthTheme.green { return .green }
    if signalTint == WealthTheme.blue { return .blue }
    if signalTint == WealthTheme.purple { return .purple }
    return .red
}

private func marketUniverseTintColor(for market: String) -> Color {
    switch WealthMarketLabels.region(for: market) {
    case "US": return WealthTheme.cyan
    case "AU": return WealthTheme.green
    case "CA": return WealthTheme.blue
    case "EU": return WealthTheme.purple
    case "APAC": return WealthTheme.orange
    case "ME": return WealthTheme.gold
    case "LATAM": return WealthTheme.orange
    case "AFRICA": return WealthTheme.cyan
    case "FX": return WealthTheme.blue
    case "CRYPTO": return WealthTheme.orange
    default: return WealthTheme.white
    }
}

private func marketPriceText(price: Double, hasQuoteData: Bool) -> String {
    if hasQuoteData {
        return WealthFormat.money(price)
    }
    return "No Data"
}

private func importedEntryTint(
    resolution: WealthIBKRInstrumentResolution,
    market: String
) -> Color {
    switch resolution.status {
    case .supportedEquity:
        return marketUniverseTintColor(for: market)
    case .delistedInactive:
        return WealthTheme.red
    case .renamedTicker, .otcOrForeignNeedsExchange:
        return WealthTheme.gold
    case .nonStandardInstrument, .invalidSymbol:
        return WealthTheme.grey
    }
}
