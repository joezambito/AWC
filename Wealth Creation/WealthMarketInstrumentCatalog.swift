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

        // MARK: - Australia (ASX)
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
            symbol: "XJO",
            market: "ASX",
            name: "S&P/ASX 200",
            instrumentType: "index",
            exchange: "ASX",
            country: "Australia",
            region: "Oceania",
            currency: "AUD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "XJO",
                yahoo: "^AXJO",
                tradingView: "ASX:XJO"
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
        ),

        // MARK: - United States
        WealthMarketInstrumentDefinition(
            symbol: "SPX",
            market: "NYSE",
            name: "S&P 500",
            instrumentType: "index",
            exchange: "NYSE",
            country: "United States",
            region: "US",
            currency: "USD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^GSPC",
                yahoo: "^GSPC",
                tradingView: "SP:SPX"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "IXIC",
            market: "NASDAQ",
            name: "NASDAQ Composite",
            instrumentType: "index",
            exchange: "NASDAQ",
            country: "United States",
            region: "US",
            currency: "USD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^IXIC",
                yahoo: "^IXIC",
                tradingView: "NASDAQ:IXIC"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "DJI",
            market: "NYSE",
            name: "Dow Jones Industrial Average",
            instrumentType: "index",
            exchange: "NYSE",
            country: "United States",
            region: "US",
            currency: "USD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^DJI",
                yahoo: "^DJI",
                tradingView: "DJ:DJI"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "RUT",
            market: "NYSE",
            name: "Russell 2000",
            instrumentType: "index",
            exchange: "NYSE",
            country: "United States",
            region: "US",
            currency: "USD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^RUT",
                yahoo: "^RUT",
                tradingView: "TVC:RUT"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),

        // MARK: - Canada
        WealthMarketInstrumentDefinition(
            symbol: "GSPTSE",
            market: "TSX",
            name: "S&P/TSX Composite",
            instrumentType: "index",
            exchange: "TSX",
            country: "Canada",
            region: "CA",
            currency: "CAD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^GSPTSE",
                yahoo: "^GSPTSE",
                tradingView: "TVC:TSX"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),

        // MARK: - Europe
        WealthMarketInstrumentDefinition(
            symbol: "UKX",
            market: "LSE",
            name: "FTSE 100",
            instrumentType: "index",
            exchange: "LSE",
            country: "United Kingdom",
            region: "EU",
            currency: "GBP",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^FTSE",
                yahoo: "^FTSE",
                tradingView: "TVC:UKX"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "DAX",
            market: "XETRA",
            name: "DAX 40",
            instrumentType: "index",
            exchange: "XETRA",
            country: "Germany",
            region: "EU",
            currency: "EUR",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^GDAXI",
                yahoo: "^GDAXI",
                tradingView: "XETRA:DAX"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "FCHI",
            market: "EURONEXT",
            name: "CAC 40",
            instrumentType: "index",
            exchange: "EURONEXT",
            country: "France",
            region: "EU",
            currency: "EUR",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^FCHI",
                yahoo: "^FCHI",
                tradingView: "EURONEXT:CAC40"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "STOXX50E",
            market: "EURONEXT",
            name: "Euro Stoxx 50",
            instrumentType: "index",
            exchange: "EURONEXT",
            country: "Europe",
            region: "EU",
            currency: "EUR",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^STOXX50E",
                yahoo: "^STOXX50E",
                tradingView: "TVC:SX5E"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),

        // MARK: - Asia Pacific
        WealthMarketInstrumentDefinition(
            symbol: "N225",
            market: "TSE",
            name: "Nikkei 225",
            instrumentType: "index",
            exchange: "TSE",
            country: "Japan",
            region: "APAC",
            currency: "JPY",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^N225",
                yahoo: "^N225",
                tradingView: "TVC:NI225"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "HSI",
            market: "HKEX",
            name: "Hang Seng Index",
            instrumentType: "index",
            exchange: "HKEX",
            country: "Hong Kong",
            region: "APAC",
            currency: "HKD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^HSI",
                yahoo: "^HSI",
                tradingView: "TVC:HSI"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "KS11",
            market: "KRX",
            name: "KOSPI",
            instrumentType: "index",
            exchange: "KRX",
            country: "South Korea",
            region: "APAC",
            currency: "KRW",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^KS11",
                yahoo: "^KS11",
                tradingView: "KRX:KOSPI"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "SENSEX",
            market: "NSE",
            name: "BSE Sensex",
            instrumentType: "index",
            exchange: "NSE",
            country: "India",
            region: "APAC",
            currency: "INR",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^BSESN",
                yahoo: "^BSESN",
                tradingView: "BSE:SENSEX"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "STI",
            market: "SGX",
            name: "Straits Times Index",
            instrumentType: "index",
            exchange: "SGX",
            country: "Singapore",
            region: "APAC",
            currency: "SGD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^STI",
                yahoo: "^STI",
                tradingView: "SGX:STI"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),

        // MARK: - Middle East
        WealthMarketInstrumentDefinition(
            symbol: "TASI",
            market: "TADAWUL",
            name: "Tadawul All Share Index",
            instrumentType: "index",
            exchange: "TADAWUL",
            country: "Saudi Arabia",
            region: "ME",
            currency: "SAR",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^TASI.SR",
                yahoo: "^TASI.SR",
                tradingView: "TADAWUL:TASI"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),

        // MARK: - Russia
        WealthMarketInstrumentDefinition(
            symbol: "IMOEX",
            market: "MOEX",
            name: "MOEX Russia Index",
            instrumentType: "index",
            exchange: "MOEX",
            country: "Russia",
            region: "EU",
            currency: "RUB",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "IMOEX.ME",
                yahoo: "IMOEX.ME",
                tradingView: "MOEX:IMOEX"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),

        // MARK: - Latin America
        WealthMarketInstrumentDefinition(
            symbol: "IBOV",
            market: "B3",
            name: "Ibovespa",
            instrumentType: "index",
            exchange: "B3",
            country: "Brazil",
            region: "LATAM",
            currency: "BRL",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "^BVSP",
                yahoo: "^BVSP",
                tradingView: "BMFBOVESPA:IBOV"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),

        // MARK: - Africa
        WealthMarketInstrumentDefinition(
            symbol: "TOP40",
            market: "JSE",
            name: "JSE Top 40",
            instrumentType: "index",
            exchange: "JSE",
            country: "South Africa",
            region: "AFRICA",
            currency: "ZAR",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "JSE.JO",
                yahoo: "JSE.JO",
                tradingView: "JSE:TOP40"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),

        // MARK: - FX
        WealthMarketInstrumentDefinition(
            symbol: "DXY",
            market: "FX",
            name: "US Dollar Index",
            instrumentType: "index",
            exchange: "FX",
            country: "Global",
            region: "FX",
            currency: "USD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "DX-Y.NYB",
                yahoo: "DX-Y.NYB",
                tradingView: "TVC:DXY"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),

        // MARK: - Crypto
        WealthMarketInstrumentDefinition(
            symbol: "BTC",
            market: "CRYPTO",
            name: "Bitcoin",
            instrumentType: "crypto",
            exchange: "CRYPTO",
            country: "Global",
            region: "CRYPTO",
            currency: "USD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "BTC-USD",
                yahoo: "BTC-USD",
                tradingView: "BINANCE:BTCUSDT"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "ETH",
            market: "CRYPTO",
            name: "Ethereum",
            instrumentType: "crypto",
            exchange: "CRYPTO",
            country: "Global",
            region: "CRYPTO",
            currency: "USD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "ETH-USD",
                yahoo: "ETH-USD",
                tradingView: "BINANCE:ETHUSDT"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),

        // MARK: - Commodities
        WealthMarketInstrumentDefinition(
            symbol: "GC",
            market: "COMEX",
            name: "Gold Futures",
            instrumentType: "commodity",
            exchange: "COMEX",
            country: "Global",
            region: "GLOBAL",
            currency: "USD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "GC=F",
                yahoo: "GC=F",
                tradingView: "TVC:GOLD"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
        ),
        WealthMarketInstrumentDefinition(
            symbol: "CL",
            market: "NYMEX",
            name: "WTI Crude Oil Futures",
            instrumentType: "commodity",
            exchange: "NYMEX",
            country: "Global",
            region: "GLOBAL",
            currency: "USD",
            providerSymbols: WealthProviderSymbolSet(
                nativeASX: "CL=F",
                yahoo: "CL=F",
                tradingView: "TVC:USOIL"
            ),
            providerFallbackOrder: [.yahoo, .tradingView]
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

    nonisolated
    static func isReferenceInstrument(symbol: String, market: String) -> Bool {
        definitionsByKey[WealthOpportunityLaneRules.laneKey(symbol: symbol, market: market)] != nil
    }
}
