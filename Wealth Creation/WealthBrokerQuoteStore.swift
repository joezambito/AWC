import Foundation
import Combine

// MARK: - WealthBrokerQuoteKey

struct WealthBrokerQuoteKey: Hashable {
    let symbol: String
    let exchange: String
}

// MARK: - WealthBrokerQuote

struct WealthBrokerQuote {
    let key: WealthBrokerQuoteKey
    let price: Double
    let bid: Double
    let ask: Double
    let updatedAt: Date
}

// MARK: - WealthBrokerQuoteStore

@MainActor
final class WealthBrokerQuoteStore: ObservableObject {

    static let shared = WealthBrokerQuoteStore()

    @Published private(set) var displayQuotes: [WealthBrokerQuote] = []

    private let timestampFormatter = ISO8601DateFormatter()
    private var cancellables: Set<AnyCancellable> = []
    private var liveQuotes: [WealthBrokerQuoteKey: WealthBrokerQuote] = [:]
    private var pendingUIRefreshTask: Task<Void, Never>?
    private var pendingQuoteUpdatesInCycle = 0
    private var brokerUIScreenVisible = false

    private init() {}
}
