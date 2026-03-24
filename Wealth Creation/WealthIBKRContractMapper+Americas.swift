import Foundation

extension WealthIBKRContractMapper {
    static func americasStockContract(
        key: WealthBrokerQuoteKey,
        symbol: String,
        market: String
    ) -> WealthIBKRContract? {
        switch market {
        case "NASDAQ", "NYSE", "AMEX", "ETF", "REIT", "ADR", "BOND", "COMMODITY":
            return stock(
                key: key,
                symbol: symbol,
                currency: "USD",
                primaryExchange: primaryExchange(for: market, symbol: symbol)
            )
        case "OTC":
            return stock(key: key, symbol: symbol, currency: "USD", primaryExchange: "PINK")
        case "TSX":
            return stock(key: key, symbol: symbol, currency: "CAD", primaryExchange: "TSE")
        case "TSXV", "CSE":
            return stock(key: key, symbol: symbol, currency: "CAD", primaryExchange: "TSE")
        case "B3":
            return stock(key: key, symbol: symbol, currency: "BRL", primaryExchange: "BOVESPA")
        case "BMV":
            return stock(key: key, symbol: symbol, currency: "MXN", primaryExchange: "BMV")
        case "BCBA":
            return stock(key: key, symbol: symbol, currency: "ARS", primaryExchange: "BCBA")
        default:
            return nil
        }
    }
}
