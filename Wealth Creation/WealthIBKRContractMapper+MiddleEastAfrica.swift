import Foundation

extension WealthIBKRContractMapper {
    static func middleEastAfricaStockContract(
        key: WealthBrokerQuoteKey,
        symbol: String,
        market: String
    ) -> WealthIBKRContract? {
        switch market {
        case "JSE":
            return stock(key: key, symbol: symbol, currency: "ZAR", primaryExchange: "JSE")
        case "KSE":
            return stock(key: key, symbol: symbol, currency: "KWD", primaryExchange: "KSE")
        case "MSX":
            return stock(key: key, symbol: symbol, currency: "OMR", primaryExchange: "MSX")
        case "BHB":
            return stock(key: key, symbol: symbol, currency: "BHD", primaryExchange: "BHB")
        case "DFM":
            return stock(key: key, symbol: symbol, currency: "AED", primaryExchange: "DFM")
        case "ADX":
            return stock(key: key, symbol: symbol, currency: "AED", primaryExchange: "ADX")
        case "QSE":
            return stock(key: key, symbol: symbol, currency: "QAR", primaryExchange: "QSE")
        case "TADAWUL":
            return stock(key: key, symbol: symbol, currency: "SAR", primaryExchange: "TADAWUL")
        case "TASE":
            return stock(key: key, symbol: symbol, currency: "ILS", primaryExchange: "TASE")
        case "EGX":
            return stock(key: key, symbol: symbol, currency: "EGP", primaryExchange: "EGX")
        default:
            return nil
        }
    }
}
