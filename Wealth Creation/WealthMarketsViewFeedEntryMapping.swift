import SwiftUI

extension MarketsView {
    // MARK: Shared Feed Mapping
    var marketFeedEntries: [MarketUniverseEntry] {
        let brokerName = WealthBrokerStore.shared.selectedBroker.name

        let liveEntries = marketLaneOpportunities.map {
            marketFeedEntry(for: $0, brokerName: brokerName)
        }

        let importedEntries = importedMarketRecordsForCurrentBatch.map {
            marketFeedEntry(for: $0, brokerName: brokerName)
        }

        return Array((liveEntries + importedEntries).prefix(100))
    }

    func marketFeedEntry(for opportunity: Opportunity, brokerName: String) -> MarketUniverseEntry {
        let brokerQuote = marketQuote(for: opportunity)
        let displayPrice = brokerQuote?.price ?? opportunity.price
        let displayChangePercent = brokerQuote?.changePercent ?? opportunity.priceChangePercent
        let hasQuoteData = brokerQuote != nil
        let isDelayed = brokerQuote?.isDelayed == true
        let isStale = brokerQuote.map { Date().timeIntervalSince($0.timestamp) > 75 } ?? true
        let hasFreshData = brokerQuote != nil && !isStale
        let aiTint = opportunity.cardSignalTint
        let marketTint = aiTint
        let priceText = brokerQuote.map { WealthFormat.money($0.price) } ?? marketPriceText(price: opportunity.price, hasQuoteData: false)
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

    func marketFeedEntry(for record: MarketUniverseRecord, brokerName: String) -> MarketUniverseEntry {
        let opportunity = marketOpportunity(for: record)
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
        let priceText = brokerQuote.map { WealthFormat.money($0.price) } ?? marketPriceText(price: price, hasQuoteData: false)
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
}

let marketQuotePendingDisplayText = "QUOTE PENDING"
let marketQuotePendingChangeDisplayText = "CHANGE --"
let marketQuotePendingAgeDisplayText = "Waiting quote"

func marketLabelBand(for opportunity: Opportunity) -> MarketUniverseLabelBand {
    let signalTint = opportunity.cardSignalTint
    if signalTint == WealthTheme.green { return .green }
    if signalTint == WealthTheme.blue { return .blue }
    if signalTint == WealthTheme.purple { return .purple }
    if signalTint == WealthTheme.red { return .red }
    return .purple
}

func marketUniverseTintColor(for market: String) -> Color {
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
    return marketQuotePendingDisplayText
}
