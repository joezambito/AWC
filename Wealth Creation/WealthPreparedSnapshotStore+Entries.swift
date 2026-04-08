import SwiftUI

extension WealthPreparedSnapshotStore {
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
