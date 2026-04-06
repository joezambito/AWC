import SwiftUI

extension MarketsView {
    // MARK: Phone Alphabet Mapping
    func shiftPhoneBucketPage(_ delta: Int) {
        let nextPage = min(max(0, selectedPhoneBucketPage + delta), max(0, selectedPhoneBucketPageCount - 1))
        phoneMarketBucketPages[selectedPhoneBucketCacheKey] = nextPage
    }

    func phoneMarketEntry(for record: MarketUniverseRecord) -> MarketUniverseEntry {
        let opportunity = marketOpportunity(for: record) ?? phoneOpportunity(for: record)
        let resolution = WealthIBKRInstrumentResolver.resolution(for: record)
        let brokerQuote = quoteStore.marketDisplayQuote(symbol: record.symbol, market: record.market)
        let aiLabel = opportunity.map { "\($0.marketQualityTier.displayLabel) · #\(max($0.rank, 1))" } ?? "RANK --"
        let confidenceText = opportunity.map { "AI \($0.aiScore) • CONF \($0.confidence)%" } ?? "AI --"
        let hasQuoteData = brokerQuote != nil
        let isDelayed = brokerQuote?.isDelayed == true
        let isStale = brokerQuote.map { Date().timeIntervalSince($0.timestamp) > 75 } ?? true
        let hasFreshData = brokerQuote != nil && !isStale
        let accentTint = opportunity?.cardSignalTint ?? phoneImportedEntryTint(resolution: resolution, market: record.market)
        let marketTint = accentTint
        let priceText = brokerQuote.map { WealthFormat.money($0.price) } ?? marketQuotePendingDisplayText
        let changeText = brokerQuote.map {
            $0.changePercent >= 0 ? "+\(WealthFormat.percent($0.changePercent))" : WealthFormat.percent($0.changePercent)
        } ?? marketQuotePendingChangeDisplayText
        let statusText: String

        if !resolution.isSupportedEquity {
            statusText = resolution.uiLabel.uppercased()
        } else if brokerQuote == nil {
            statusText = marketQuotePendingDisplayText
        } else if isDelayed {
            statusText = "DELAYED"
        } else {
            statusText = "LIVE"
        }

        let whyText: String
        if !resolution.isSupportedEquity {
            whyText = resolution.reason
        } else if brokerQuote == nil, WealthSyncStore.shared.isTWSConnectedForQuotes {
            whyText = "Visible bucket subscription sent. Waiting for IBKR ticks."
        } else if brokerQuote == nil {
            whyText = "Waiting for delayed/offline quote for this visible bucket."
        } else {
            whyText = record.companyName ?? "\(record.assetTypeDisplay) instrument"
        }

        return MarketUniverseEntry(
            id: record.id,
            symbol: record.symbol,
            market: record.market,
            marketDisplayLabel: resolution.resolvedExchange ?? record.marketDisplayLabel,
            region: phoneMarketCode(for: record),
            sector: record.assetTypeDisplay,
            price: brokerQuote?.price ?? 0,
            priceChangePercent: brokerQuote?.changePercent ?? 0,
            hasQuoteData: hasQuoteData,
            isDelayed: isDelayed,
            priceText: priceText,
            aiScoreText: aiLabel,
            changeText: changeText,
            confidenceText: confidenceText,
            backingOpportunityKey: opportunity.map(WealthOpportunityLaneRules.laneKey),
            statusText: statusText,
            dataAgeText: brokerQuote.map { WealthFormat.age($0.timestamp) } ?? (!resolution.isSupportedEquity ? resolution.uiLabel : marketQuotePendingAgeDisplayText),
            nextTradeText: BrokerSessionClock.nextTradingText(for: record.market, brokerName: WealthBrokerStore.shared.selectedBroker.name),
            whyText: whyText,
            tint: marketTint,
            backgroundTint: marketTint,
            borderTint: marketTint,
            hasFreshData: hasFreshData,
            aiLabelBand: opportunity.map(phoneMarketLabelBand(for:)),
            shieldExitPrice: opportunity?.shieldExitPrice,
            surgeExitPrice: opportunity?.surgeExitPrice,
            shieldTriggerPercent: opportunity?.shieldTriggerPercent,
            surgeTriggerPercent: opportunity?.surgeTriggerPercent,
            hasBackingOpportunity: opportunity != nil
        )
    }

    private func phoneOpportunity(for record: MarketUniverseRecord) -> Opportunity? {
        let key = WealthOpportunityLaneRules.laneKey(symbol: record.symbol, market: record.market)
        return phoneOpportunityLookup[key]
    }
}

private func phoneMarketLabelBand(for opportunity: Opportunity) -> MarketUniverseLabelBand {
    let signalTint = opportunity.cardSignalTint
    if signalTint == WealthTheme.green { return .green }
    if signalTint == WealthTheme.blue { return .blue }
    if signalTint == WealthTheme.purple { return .purple }
    return .purple
}

private func phoneMarketUniverseTintColor(for market: String) -> Color {
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

private func phoneImportedEntryTint(
    resolution: WealthIBKRInstrumentResolution,
    market: String
) -> Color {
    switch resolution.status {
    case .supportedEquity:
        return phoneMarketUniverseTintColor(for: market)
    case .delistedInactive:
        return WealthTheme.red
    case .renamedTicker, .otcOrForeignNeedsExchange:
        return WealthTheme.gold
    case .nonStandardInstrument, .invalidSymbol:
        return WealthTheme.red
    }
}
