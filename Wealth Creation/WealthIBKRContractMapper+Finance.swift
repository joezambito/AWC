import Foundation

extension WealthIBKRContractMapper {
    static func indexedContract(
        key: WealthBrokerQuoteKey,
        symbol: String,
        market: String
    ) -> WealthIBKRContract? {
        guard let definition = WealthMarketInstrumentCatalog.definition(symbol: symbol, market: market) else {
            return nil
        }

        guard definition.instrumentType.lowercased() == "index" else { return nil }

        return WealthIBKRContract(
            key: key,
            symbol: symbol,
            secType: "IND",
            exchange: definition.exchange,
            currency: definition.currency,
            localSymbol: definition.providerSymbols.nativeASX,
            tradingClass: definition.providerSymbols.nativeASX
        )
    }

    static func financeContract(
        key: WealthBrokerQuoteKey,
        symbol: String,
        market: String
    ) -> WealthIBKRContract? {
        if let indexed = indexedContract(key: key, symbol: symbol, market: market) {
            return indexed
        }

        switch market {
        case "CRYPTO":
            return WealthIBKRContract(
                key: key,
                symbol: symbol,
                secType: "CRYPTO",
                exchange: "PAXOS",
                currency: "USD"
            )
        case "FX":
            guard symbol.count == 6 else { return nil }
            return WealthIBKRContract(
                key: key,
                symbol: String(symbol.prefix(3)),
                secType: "CASH",
                exchange: "IDEALPRO",
                currency: String(symbol.suffix(3))
            )
        default:
            return nil
        }
    }

    static func stock(
        key: WealthBrokerQuoteKey,
        symbol: String,
        currency: String,
        primaryExchange: String
    ) -> WealthIBKRContract {
        WealthIBKRContract(
            key: key,
            symbol: symbol,
            secType: "STK",
            exchange: "SMART",
            primaryExchange: primaryExchange,
            currency: currency
        )
    }

    static func primaryExchange(for market: String, symbol: String) -> String {
        switch market {
        case "ETF", "REIT", "ADR":
            return ""
        case "BOND":
            return "ARCA"
        case "COMMODITY":
            return symbol == "GOLD" ? "ARCA" : ""
        default:
            return market
        }
    }
}
