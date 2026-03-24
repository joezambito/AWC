import Foundation
import Combine

@MainActor
final class WealthLiveMarketDataStore: ObservableObject {
    static let shared = WealthLiveMarketDataStore()

    struct SymbolDiagnostics: Identifiable, Hashable {
        let id: String
        let key: WealthBrokerQuoteKey
        var contract: WealthIBKRContract?
        var requestID: Int?
        var reqMktDataSent = false
        var tickPriceCount = 0
        var tickSizeCount = 0
        var lastTickAt: Date?
        var lastErrorCode: Int?
        var lastErrorMessage: String?

        var symbolLabel: String {
            "\(key.symbol) \(key.market)"
        }

        var statusLabel: String {
            if let lastErrorCode, [354, 10167].contains(lastErrorCode) {
                return "NO PERMISSION"
            }
            if reqMktDataSent && lastTickAt == nil {
                return "NO TICKS"
            }
            if lastTickAt != nil {
                return "LIVE"
            }
            return "WAITING"
        }
    }

    struct ErrorSnapshot: Identifiable, Hashable {
        let id: String
        let code: Int?
        let message: String
        let requestID: Int?
        let timestamp: Date
    }

    @Published private(set) var twsConnected = false
    @Published private(set) var connectionStatus = "TWS OFFLINE"
    @Published private(set) var connectionHost = "127.0.0.1"
    @Published private(set) var connectionPort = 7497
    @Published private(set) var clientID = 0
    @Published private(set) var marketDataType = 1
    @Published private(set) var lastTickReceivedAt: Date?
    @Published private(set) var lastConnectionMessage = ""
    @Published private(set) var liveQuotes: [WealthBrokerQuoteKey: WealthBrokerQuote] = [:]
    @Published private(set) var symbolDiagnostics: [String: SymbolDiagnostics] = [:]
    @Published private(set) var recentErrors: [ErrorSnapshot] = []
    @Published private(set) var invalidContracts: [WealthBrokerQuoteKey] = []
    @Published private(set) var apiPort = 8787

    private let timestampFormatter = ISO8601DateFormatter()
    private init() {}

    var symbolDiagnosticsList: [SymbolDiagnostics] {
        symbolDiagnostics.values.sorted { lhs, rhs in
            let leftDate = lhs.lastTickAt ?? .distantPast
            let rightDate = rhs.lastTickAt ?? .distantPast
            if leftDate != rightDate { return leftDate > rightDate }
            return lhs.symbolLabel < rhs.symbolLabel
        }
    }

    var endpointLabel: String {
        "http://127.0.0.1:\(apiPort)/api/prices"
    }

    var noTickDiagnostics: [SymbolDiagnostics] {
        symbolDiagnosticsList.filter { $0.reqMktDataSent && $0.lastTickAt == nil }
    }

    var noPermissionDiagnostics: [SymbolDiagnostics] {
        symbolDiagnosticsList.filter { item in
            guard let code = item.lastErrorCode else { return false }
            return [354, 10167].contains(code)
        }
    }

    func setAPIPort(_ port: Int) {
        apiPort = port
    }

    func setInvalidContracts(_ keys: [WealthBrokerQuoteKey]) {
        invalidContracts = keys.sorted {
            if $0.market != $1.market { return $0.market < $1.market }
            return $0.symbol < $1.symbol
        }
    }

    func noteConnectionAttempt(host: String, port: Int, clientID: Int) {
        connectionHost = host
        connectionPort = port
        self.clientID = clientID
        connectionStatus = "CONNECTING"
        lastConnectionMessage = "Trying \(host):\(port)"
    }

    func noteConnected(host: String, port: Int, clientID: Int) {
        connectionHost = host
        connectionPort = port
        self.clientID = clientID
        twsConnected = true
        connectionStatus = "TWS CONNECTED"
        lastConnectionMessage = "Connected to \(host):\(port)"
    }

    func noteDisconnected(_ message: String) {
        twsConnected = false
        connectionStatus = "TWS OFFLINE"
        lastConnectionMessage = message
    }

    func noteFailed(_ message: String) {
        twsConnected = false
        connectionStatus = "TWS FAILED"
        lastConnectionMessage = message
    }

    func noteMarketDataType(_ type: Int) {
        marketDataType = type
    }

    func noteSubscription(contract: WealthIBKRContract, requestID: Int) {
        updateDiagnostics(for: contract.key) { item in
            item.contract = contract
            item.requestID = requestID
            item.reqMktDataSent = true
        }
    }

    func noteTickPrice(key: WealthBrokerQuoteKey, requestID: Int, contract: WealthIBKRContract?, tickType: Int, timestamp: Date) {
        updateDiagnostics(for: key) { item in
            item.contract = contract
            item.requestID = requestID
            item.tickPriceCount += 1
            item.lastTickAt = timestamp
        }
        lastTickReceivedAt = timestamp
    }

    func noteTickSize(key: WealthBrokerQuoteKey, requestID: Int, contract: WealthIBKRContract?, tickType: Int, timestamp: Date) {
        updateDiagnostics(for: key) { item in
            item.contract = contract
            item.requestID = requestID
            item.tickSizeCount += 1
            item.lastTickAt = timestamp
        }
        lastTickReceivedAt = timestamp
    }

    func noteQuote(_ quote: WealthBrokerQuote) {
        liveQuotes[quote.key] = quote
        updateDiagnostics(for: quote.key) { item in
            item.lastTickAt = quote.timestamp
        }
        lastTickReceivedAt = quote.timestamp
    }

    func noteError(code: Int?, message: String, requestID: Int?, key: WealthBrokerQuoteKey?) {
        let error = ErrorSnapshot(
            id: "\(requestID ?? -1)-\(code ?? -1)-\(Date().timeIntervalSince1970)",
            code: code,
            message: message,
            requestID: requestID,
            timestamp: .now
        )
        recentErrors.insert(error, at: 0)
        recentErrors = Array(recentErrors.prefix(12))

        if let key {
            updateDiagnostics(for: key) { item in
                item.lastErrorCode = code
                item.lastErrorMessage = message
            }
        }
    }

    func clearQuotes() {
        liveQuotes.removeAll()
        lastTickReceivedAt = nil
    }

    func apiResponseData(path: String) -> Data {
        let payload: APIPayload
        if let symbol = Self.requestedSymbol(from: path) {
            let filtered = liveQuotes.filter { $0.key.symbol.caseInsensitiveCompare(symbol) == .orderedSame }
            payload = makePayload(quotes: filtered)
        } else {
            payload = makePayload(quotes: liveQuotes)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(payload)) ?? Data("{}".utf8)
    }

    private func makePayload(quotes: [WealthBrokerQuoteKey: WealthBrokerQuote]) -> APIPayload {
        APIPayload(
            twsConnected: twsConnected,
            connectionStatus: connectionStatus,
            host: connectionHost,
            port: connectionPort,
            clientID: clientID,
            marketDataType: marketDataType,
            lastTickReceivedAt: lastTickReceivedAt,
            quotes: quotes.values
                .sorted { lhs, rhs in
                    if lhs.key.market != rhs.key.market { return lhs.key.market < rhs.key.market }
                    return lhs.key.symbol < rhs.key.symbol
                }
                .map { quote in
                    APIQuote(
                        symbol: quote.key.symbol,
                        market: quote.key.market,
                        price: quote.price,
                        close: quote.close,
                        bid: quote.bid,
                        ask: quote.ask,
                        bidSize: quote.bidSize,
                        askSize: quote.askSize,
                        lastSize: quote.lastSize,
                        currency: quote.currency,
                        timestamp: quote.timestamp,
                        isDelayed: quote.isDelayed
                    )
                },
            diagnostics: symbolDiagnosticsList.map { item in
                APIDiagnostics(
                    symbol: item.key.symbol,
                    market: item.key.market,
                    status: item.statusLabel,
                    requestID: item.requestID,
                    reqMktDataSent: item.reqMktDataSent,
                    tickPriceCount: item.tickPriceCount,
                    tickSizeCount: item.tickSizeCount,
                    lastTickAt: item.lastTickAt,
                    contract: item.contract.map {
                        APIContract(
                            symbol: $0.symbol,
                            secType: $0.secType,
                            exchange: $0.exchange,
                            primaryExchange: $0.primaryExchange,
                            currency: $0.currency
                        )
                    },
                    lastErrorCode: item.lastErrorCode,
                    lastErrorMessage: item.lastErrorMessage
                )
            },
            recentErrors: recentErrors.map {
                APIError(code: $0.code, message: $0.message, requestID: $0.requestID, timestamp: $0.timestamp)
            },
            invalidContracts: invalidContracts.map { APIInvalidContract(symbol: $0.symbol, market: $0.market) }
        )
    }

    private func updateDiagnostics(for key: WealthBrokerQuoteKey, update: (inout SymbolDiagnostics) -> Void) {
        let itemKey = WealthOpportunityLaneRules.laneKey(symbol: key.symbol, market: key.market)
        var item = symbolDiagnostics[itemKey] ?? SymbolDiagnostics(id: itemKey, key: key)
        update(&item)
        symbolDiagnostics[itemKey] = item
    }

    private static func requestedSymbol(from path: String) -> String? {
        guard let components = URLComponents(string: "http://localhost\(path)") else { return nil }
        return components.queryItems?.first(where: { $0.name == "symbol" })?.value
    }
}

private extension WealthLiveMarketDataStore {
    struct APIPayload: Encodable {
        let twsConnected: Bool
        let connectionStatus: String
        let host: String
        let port: Int
        let clientID: Int
        let marketDataType: Int
        let lastTickReceivedAt: Date?
        let quotes: [APIQuote]
        let diagnostics: [APIDiagnostics]
        let recentErrors: [APIError]
        let invalidContracts: [APIInvalidContract]
    }

    struct APIQuote: Encodable {
        let symbol: String
        let market: String
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
    }

    struct APIDiagnostics: Encodable {
        let symbol: String
        let market: String
        let status: String
        let requestID: Int?
        let reqMktDataSent: Bool
        let tickPriceCount: Int
        let tickSizeCount: Int
        let lastTickAt: Date?
        let contract: APIContract?
        let lastErrorCode: Int?
        let lastErrorMessage: String?
    }

    struct APIContract: Encodable {
        let symbol: String
        let secType: String
        let exchange: String
        let primaryExchange: String
        let currency: String
    }

    struct APIError: Encodable {
        let code: Int?
        let message: String
        let requestID: Int?
        let timestamp: Date
    }

    struct APIInvalidContract: Encodable {
        let symbol: String
        let market: String
    }
}
