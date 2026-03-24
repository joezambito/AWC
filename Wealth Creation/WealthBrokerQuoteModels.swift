import Foundation

struct WealthBrokerQuoteKey: Hashable {
    let symbol: String
    let market: String
}

struct WealthBrokerQuote: Hashable {
    let key: WealthBrokerQuoteKey
    let price: Double
    let close: Double?
    let bid: Double?
    let ask: Double?
    let bidSize: Int?
    let askSize: Int?
    let lastSize: Int?
    let currency: String
    let timestamp: Date
    let isDelayed: Bool

    var changePercent: Double {
        guard let close, close > 0 else { return 0 }
        return ((price / close) - 1) * 100
    }
}

struct WealthIBKRContract: Hashable {
    let key: WealthBrokerQuoteKey
    let symbol: String
    let secType: String
    let exchange: String
    let primaryExchange: String
    let currency: String
    let localSymbol: String
    let tradingClass: String
    let genericTickList: String
    let snapshot: Bool
    let regulatorySnapshot: Bool

    init(
        key: WealthBrokerQuoteKey,
        symbol: String,
        secType: String,
        exchange: String,
        primaryExchange: String = "",
        currency: String,
        localSymbol: String = "",
        tradingClass: String = "",
        genericTickList: String = "",
        snapshot: Bool = false,
        regulatorySnapshot: Bool = false
    ) {
        self.key = key
        self.symbol = symbol
        self.secType = secType
        self.exchange = exchange
        self.primaryExchange = primaryExchange
        self.currency = currency
        self.localSymbol = localSymbol
        self.tradingClass = tradingClass
        self.genericTickList = genericTickList
        self.snapshot = snapshot
        self.regulatorySnapshot = regulatorySnapshot
    }
}
