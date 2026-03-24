import Foundation
import Combine

@MainActor
final class WealthBrokerQuoteStore: ObservableObject {
    static let shared = WealthBrokerQuoteStore()

    @Published private(set) var quotes: [WealthBrokerQuoteKey: WealthBrokerQuote] = [:]

    private init() {}

    func prepareSubscriptions(for blueprints: [OpportunityBlueprint]) {
        guard WealthSyncStore.shared.syncStatus.contains("TWS") else { return }

        let marketContracts = blueprints.compactMap(WealthIBKRContractMapper.contract(for:))
        let fxContracts = Set(
            marketContracts.compactMap { WealthFXConversionStore.fxContract(for: $0.currency) }
        )
        let useDelayed = WealthProtectionSettingsStore.shared.demoMode || !WealthSyncStore.shared.liveMode
        WealthIBKRBridge.shared.subscribe(to: Array(Set(marketContracts).union(fxContracts)), delayedQuotes: useDelayed)
    }

    func prepareSubscriptions(for records: [MarketUniverseRecord]) {
        let useDelayed = WealthProtectionSettingsStore.shared.demoMode || !WealthSyncStore.shared.liveMode
        let invalidContracts = records
            .filter { !WealthIBKRInstrumentResolver.resolution(for: $0).isSupportedEquity }
            .map { WealthBrokerQuoteKey(symbol: $0.symbol, market: $0.market) }
        WealthLiveMarketDataStore.shared.setInvalidContracts(invalidContracts)
        if WealthSyncStore.shared.syncStatus.contains("TWS") {
            WealthWorldMarketOfflineQuotePass.shared.stop()
            WealthWorldMarketBulkQuotePass.shared.start(
                records: records,
                quotes: quotes,
                delayedQuotes: useDelayed
            )
        } else {
            WealthWorldMarketBulkQuotePass.shared.stop()
            WealthWorldMarketOfflineQuotePass.shared.start(records: records)
        }
    }

    func ingest(_ quote: WealthBrokerQuote) {
        quotes[quote.key] = quote
        WealthLiveMarketDataStore.shared.noteQuote(quote)
    }

    func clear() {
        quotes.removeAll()
        WealthLiveMarketDataStore.shared.clearQuotes()
        WealthWorldMarketBulkQuotePass.shared.stop()
        WealthWorldMarketOfflineQuotePass.shared.stop()
    }

    func marketDisplayQuote(symbol: String, market: String) -> WealthBrokerQuote? {
        let exactKey = WealthBrokerQuoteKey(symbol: symbol, market: market)
        if let exact = quotes[exactKey] {
            return exact
        }

        let symbolMatches = quotes.values.filter {
            $0.key.symbol.caseInsensitiveCompare(symbol) == .orderedSame
        }

        if symbolMatches.count == 1 {
            return symbolMatches.first
        }

        return symbolMatches.first {
            $0.key.market.caseInsensitiveCompare(market) == .orderedSame
        }
    }

    func liveQuote(
        for blueprint: OpportunityBlueprint,
        previous: Opportunity?,
        refreshTime: Date,
        sessionOpen: Bool
    ) -> WealthLiveQuote {
        let key = WealthBrokerQuoteKey(symbol: blueprint.symbol, market: blueprint.market)

        if let brokerQuote = quotes[key] {
            let conversionRate = WealthFXConversionStore.rateToAUD(for: brokerQuote.currency, quotes: quotes)
            let convertedPrice = brokerQuote.price * conversionRate
            let convertedClose = (brokerQuote.close ?? brokerQuote.price) * conversionRate
            return WealthLiveQuote(
                price: convertedPrice,
                changePercent: convertedClose > 0 ? ((convertedPrice / convertedClose) - 1) * 100 : brokerQuote.changePercent,
                dataAge: max(0, refreshTime.timeIntervalSince(brokerQuote.timestamp))
            )
        }

        let fallback = WealthLivePricingEngine.quote(
            for: blueprint,
            previous: previous,
            refreshTime: refreshTime,
            sessionOpen: sessionOpen
        )
        let currency = WealthIBKRContractMapper.contract(for: blueprint)?.currency ?? "AUD"
        let conversionRate = WealthFXConversionStore.rateToAUD(for: currency, quotes: quotes)

        return WealthLiveQuote(
            price: fallback.price * conversionRate,
            changePercent: fallback.changePercent,
            dataAge: fallback.dataAge
        )
    }
}
