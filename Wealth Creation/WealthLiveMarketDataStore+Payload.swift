import Foundation

extension WealthLiveMarketDataStore {
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
