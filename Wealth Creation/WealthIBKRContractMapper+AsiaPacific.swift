import Foundation

extension WealthIBKRContractMapper {
    static func asiaPacificStockContract(
        key: WealthBrokerQuoteKey,
        symbol: String,
        market: String
    ) -> WealthIBKRContract? {
        switch market {
        case "ASX":
            return stock(key: key, symbol: symbol, currency: "AUD", primaryExchange: "ASX")
        case "TSE":
            return stock(key: key, symbol: symbol, currency: "JPY", primaryExchange: "TSEJ")
        case "HKEX":
            return stock(key: key, symbol: symbol, currency: "HKD", primaryExchange: "SEHK")
        case "SSE":
            return stock(key: key, symbol: symbol, currency: "CNY", primaryExchange: "SEHKNTL")
        case "SZSE":
            return stock(key: key, symbol: symbol, currency: "CNY", primaryExchange: "SEHKSZSE")
        case "KRX":
            return stock(key: key, symbol: symbol, currency: "KRW", primaryExchange: "KSE")
        case "SGX":
            return stock(key: key, symbol: symbol, currency: "SGD", primaryExchange: "SGX")
        case "NSE":
            return stock(key: key, symbol: symbol, currency: "INR", primaryExchange: "NSE")
        case "BSE":
            return stock(key: key, symbol: symbol, currency: "INR", primaryExchange: "BSE")
        case "TWSE":
            return stock(key: key, symbol: symbol, currency: "TWD", primaryExchange: "TSE")
        case "TPEX":
            return stock(key: key, symbol: symbol, currency: "TWD", primaryExchange: "ROCO")
        case "NZX":
            return stock(key: key, symbol: symbol, currency: "NZD", primaryExchange: "NZE")
        case "SET":
            return stock(key: key, symbol: symbol, currency: "THB", primaryExchange: "SET")
        case "IDX":
            return stock(key: key, symbol: symbol, currency: "IDR", primaryExchange: "IDX")
        case "BURSA":
            return stock(key: key, symbol: symbol, currency: "MYR", primaryExchange: "BURSA")
        case "PSE":
            return stock(key: key, symbol: symbol, currency: "PHP", primaryExchange: "PSE")
        case "HOSE":
            return stock(key: key, symbol: symbol, currency: "VND", primaryExchange: "HOSE")
        case "HNX":
            return stock(key: key, symbol: symbol, currency: "VND", primaryExchange: "HNX")
        default:
            return nil
        }
    }
}
