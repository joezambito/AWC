import Foundation

enum WealthQuoteProvider: String, CaseIterable {
    case nativeASX = "asx"
    case yahoo
    case tradingView = "tradingview"
}

struct WealthProviderSymbolSet: Hashable {
    let nativeASX: String
    let yahoo: String
    let tradingView: String

    nonisolated func symbol(for provider: WealthQuoteProvider) -> String {
        switch provider {
        case .nativeASX:
            return nativeASX
        case .yahoo:
            return yahoo
        case .tradingView:
            return tradingView
        }
    }
}

struct WealthMarketInstrumentDefinition: Hashable {
    let symbol: String
    let market: String
    let name: String
    let instrumentType: String
    let exchange: String
    let country: String
    let region: String
    let currency: String
    let providerSymbols: WealthProviderSymbolSet
    let providerFallbackOrder: [WealthQuoteProvider]

    nonisolated var key: String {
        WealthOpportunityLaneRules.laneKey(symbol: symbol, market: market)
    }

    nonisolated func makeUniverseRecord() -> MarketUniverseRecord {
        MarketUniverseRecord(
            symbol: symbol,
            name: name,
            assetType: instrumentType,
            country: country,
            region: region,
            exchange: exchange,
            market: market,
            currency: currency,
            isin: "",
            provider: "Built-in Index Catalog",
            isActive: true
        )
    }
}

enum WealthMarketInstrumentCatalog {
    nonisolated private static let definitions: [WealthMarketInstrumentDefinition] = [
        WealthMarketInstrumentDefinition(
            symbol: "XAO",
            market: "ASX",
            name: "All Ordinaries",
            instrumentType: "index",
            exchange: "ASX",
            country: "Australia",
            region: "Oceania",
            currency: "AUD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "XAO",
                yahoo: "^AORD",
                tradingView: "ASX:XAO"
            ),
            providerFallbackOrder: [.nativeASX, .tradingView, .yahoo]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "XTO",
            market: "ASX",
            name: "S&P/ASX 100",
            instrumentType: "index",
            exchange: "ASX",
            country: "Australia",
            region: "Oceania",
            currency: "AUD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "XTO",
                yahoo: "^ATOI",
                tradingView: "ASX:XTO"
            ),
            providerFallbackOrder: [.nativeASX, .tradingView, .yahoo]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "XSO",
            market: "ASX",
            name: "S&P/ASX Small Ordinaries",
            instrumentType: "index",
            exchange: "ASX",
            country: "Australia",
            region: "Oceania",
            currency: "AUD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "XSO",
                yahoo: "^AXSO",
                tradingView: "ASX:XSO"
            ),
            providerFallbackOrder: [.nativeASX, .tradingView, .yahoo]
        )
    ]

    nonisolated private static let definitionsByKey = Dictionary(uniqueKeysWithValues: definitions.map { ($0.key, $0) })

    nonisolated
    static var additionalUniverseRecords: [MarketUniverseRecord] {
        definitions.map { $0.makeUniverseRecord() }
    }

    nonisolated
    static func definition(symbol: String, market: String) -> WealthMarketInstrumentDefinition? {
        definitionsByKey[WealthOpportunityLaneRules.laneKey(symbol: symbol, market: market)]
    }

    nonisolated
    static func providerSymbol(
        symbol: String,
        market: String,
        preferredProvider: WealthQuoteProvider
    ) -> String? {
        definition(symbol: symbol, market: market)?.providerSymbols.symbol(for: preferredProvider)
    }

    nonisolated
    static func providerFallbackSymbols(symbol: String, market: String) -> [String] {
        guard let definition = definition(symbol: symbol, market: market) else { return [] }
        return definition.providerFallbackOrder.map { definition.providerSymbols.symbol(for: $0) }
    }
}
