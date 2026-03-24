import Foundation

enum WealthIBKRContractMapper {
    static func contract(for blueprint: OpportunityBlueprint) -> WealthIBKRContract? {
        let market = normalizedMarketCode(
            exchange: blueprint.market,
            market: blueprint.market,
            assetType: "",
            provider: ""
        )

        return contract(
            key: WealthBrokerQuoteKey(symbol: blueprint.symbol, market: blueprint.market),
            symbol: blueprint.symbol,
            market: market
        )
    }

    static func contract(for record: MarketUniverseRecord) -> WealthIBKRContract? {
        let market = normalizedMarketCode(
            exchange: record.exchange,
            market: record.market,
            assetType: record.assetType,
            provider: record.provider
        )

        return contract(
            key: WealthBrokerQuoteKey(symbol: record.symbol, market: record.market),
            symbol: record.symbol,
            market: market
        )
    }

    private static func contract(
        key: WealthBrokerQuoteKey,
        symbol rawSymbol: String,
        market rawMarket: String
    ) -> WealthIBKRContract? {
        let market = rawMarket.uppercased()
        let symbol = rawSymbol.uppercased()

        return financeContract(key: key, symbol: symbol, market: market)
            ?? americasStockContract(key: key, symbol: symbol, market: market)
            ?? europeStockContract(key: key, symbol: symbol, market: market)
            ?? asiaPacificStockContract(key: key, symbol: symbol, market: market)
            ?? middleEastAfricaStockContract(key: key, symbol: symbol, market: market)
    }

    private static func normalizedMarketCode(
        exchange rawExchange: String,
        market rawMarket: String,
        assetType rawAssetType: String,
        provider rawProvider: String
    ) -> String {
        let exchange = rawExchange.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let market = rawMarket.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let assetType = rawAssetType.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let provider = rawProvider.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if let normalizedExchange = normalizedExchangeCode(exchange, assetType: assetType) {
            return normalizedExchange
        }

        if assetType == "INDICES" || assetType == "INDEX" {
            return market
        }

        if provider == "FINANCEDATABASE", let normalizedMarket = normalizedMarketLabel(market) {
            return normalizedMarket
        }

        return market
    }

    private static func normalizedExchangeCode(_ exchange: String, assetType: String) -> String? {
        switch exchange {
        case "NAS", "NMS", "NGM", "NCM":
            return "NASDAQ"
        case "NYQ", "NYS":
            return "NYSE"
        case "ASE", "PCX", "ARC", "AMEX":
            return "AMEX"
        case "PNK", "OTC", "OBB":
            return "OTC"
        case "CCC":
            return "CRYPTO"
        case "CCY":
            return "FX"
        case "TSE":
            return "TSX"
        case "VSE":
            return "TSXV"
        case "ASX", "LSE", "SIX", "OMX", "XETRA", "BME", "BIT", "WSE", "OSE", "BIST", "MOEX",
             "HKEX", "SSE", "SZSE", "KRX", "SGX", "NSE", "BSE", "TWSE", "TPEX", "NZX", "SET", "IDX", "BURSA",
             "PSE", "HOSE", "HNX", "JSE", "KSE", "MSX", "BHB", "DFM", "ADX", "QSE", "TADAWUL",
             "TASE", "EGX", "BMV", "BCBA", "B3":
            return exchange
        case "":
            if assetType == "INDEX" || assetType == "INDICES" {
                return nil
            }
            return nil
        default:
            return nil
        }
    }

    private static func normalizedMarketLabel(_ market: String) -> String? {
        switch market {
        case "NASDAQ GLOBAL SELECT", "NASDAQ CAPITAL MARKET", "NASDAQ GLOBAL MARKET", "NAS":
            return "NASDAQ"
        case "NEW YORK STOCK EXCHANGE", "NYSE MKT", "NYSE ARCA", "NYSE":
            return market.contains("ARCA") ? "AMEX" : "NYSE"
        case "OTC BULLETIN BOARD", "PINK SHEETS":
            return "OTC"
        case "CRYPTO":
            return "CRYPTO"
        case "FX":
            return "FX"
        case "ASX":
            return "ASX"
        case "TSX":
            return "TSX"
        case "TSXV":
            return "TSXV"
        case "LSE":
            return "LSE"
        case "EURONEXT":
            return "EURONEXT"
        case "SIX":
            return "SIX"
        case "OMX":
            return "OMX"
        case "XETRA":
            return "XETRA"
        case "HKEX":
            return "HKEX"
        case "SSE":
            return "SSE"
        case "SZSE":
            return "SZSE"
        case "KRX":
            return "KRX"
        case "SGX":
            return "SGX"
        case "NSE":
            return "NSE"
        case "BSE":
            return "BSE"
        case "TWSE":
            return "TWSE"
        case "TPEX":
            return "TPEX"
        case "SET":
            return "SET"
        case "IDX":
            return "IDX"
        case "BURSA":
            return "BURSA"
        case "PSE":
            return "PSE"
        case "HOSE":
            return "HOSE"
        case "HNX":
            return "HNX"
        case "NZX":
            return "NZX"
        case "JSE":
            return "JSE"
        case "DFM":
            return "DFM"
        case "ADX":
            return "ADX"
        case "QSE":
            return "QSE"
        case "TADAWUL":
            return "TADAWUL"
        case "TASE":
            return "TASE"
        case "KSE":
            return "KSE"
        case "MSX":
            return "MSX"
        case "BHB":
            return "BHB"
        case "EGX":
            return "EGX"
        case "BMV":
            return "BMV"
        case "BCBA":
            return "BCBA"
        case "B3":
            return "B3"
        default:
            return nil
        }
    }
}
