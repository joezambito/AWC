import Foundation

extension WealthIBKRContractMapper {
    static func europeStockContract(
        key: WealthBrokerQuoteKey,
        symbol: String,
        market: String
    ) -> WealthIBKRContract? {
        switch market {
        case "LSE":
            return stock(key: key, symbol: symbol, currency: "GBP", primaryExchange: "LSE")
        case "EURONEXT":
            return stock(key: key, symbol: symbol, currency: "EUR", primaryExchange: "AEB")
        case "SIX":
            return stock(key: key, symbol: symbol, currency: "CHF", primaryExchange: "EBS")
        case "OMX":
            return stock(key: key, symbol: symbol, currency: "SEK", primaryExchange: "SFB")
        case "XETRA":
            return stock(key: key, symbol: symbol, currency: "EUR", primaryExchange: "IBIS")
        case "BME":
            return stock(key: key, symbol: symbol, currency: "EUR", primaryExchange: "BM")
        case "BIT":
            return stock(key: key, symbol: symbol, currency: "EUR", primaryExchange: "BVME")
        case "VSE":
            return stock(key: key, symbol: symbol, currency: "EUR", primaryExchange: "VSE")
        case "WSE":
            return stock(key: key, symbol: symbol, currency: "PLN", primaryExchange: "WSE")
        case "OSE":
            return stock(key: key, symbol: symbol, currency: "NOK", primaryExchange: "OSE")
        case "BIST":
            return stock(key: key, symbol: symbol, currency: "TRY", primaryExchange: "IBIS")
        case "MOEX":
            return stock(key: key, symbol: symbol, currency: "RUB", primaryExchange: "MOEX")
        default:
            return nil
        }
    }
}
