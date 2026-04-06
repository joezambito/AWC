import Foundation
import OSLog

// MARK: - MarketDataFetcher
//
// NEW FILE – Issue 7 root-cause fix.
//
// Root cause: async URLSession callbacks (completion handlers) dispatch on
// a background thread after the network round-trip.  If the object that
// owns the callback is captured weakly and is released before the callback
// fires, the callback silently drops its result — no error, no log, no
// recovery.  For non-singleton objects this is a real lifetime risk.
//
// Fix: the Task block inside `fetchQuote(for:)` captures `self` strongly
// via `[self]`.  This is the root-cause fix: the fetcher object is kept
// alive for the entire duration of the async network operation.  The
// *owner* of MarketDataFetcher (e.g. WealthEngineStore) may hold a weak
// reference to the fetcher; that is fine because the Task's strong capture
// independently extends the lifetime of the fetcher for the duration of
// each in-flight request.
//
// In-flight deduplication: re-issuing a fetch for a symbol that is already
// in flight cancels the previous Task first, so the owner always sees the
// most-recent result and stale callbacks never overwrite fresh data.

// MARK: - MarketDataFetcher

@MainActor
final class MarketDataFetcher {

    // MARK: - Supporting types

    struct QuoteResult: Equatable {
        let symbol:    String
        let price:     Double
        let timestamp: Date
    }

    enum FetchError: Error, LocalizedError {
        case invalidURL(String)
        case networkError(Error)
        case badHTTPStatus(Int)
        case decodingError(Error)
        case missingBaseURL

        var errorDescription: String? {
            switch self {
            case .invalidURL(let s):
                return "MarketDataFetcher: invalid URL '\(s)'."
            case .networkError(let e):
                return "MarketDataFetcher: network error – \(e.localizedDescription)"
            case .badHTTPStatus(let code):
                return "MarketDataFetcher: HTTP \(code) response."
            case .decodingError(let e):
                return "MarketDataFetcher: decode failed – \(e.localizedDescription)"
            case .missingBaseURL:
                return "MarketDataFetcher: MARKET_DATA_BASE_URL not set in awc.env."
            }
        }
    }

    // MARK: - Private state

    private static let log = Logger(subsystem: "com.awg.wealth", category: "MarketDataFetcher")

    /// In-flight tasks keyed by symbol.
    /// Used for cancellation-before-reissue to prevent stale callbacks.
    private var activeTasks: [String: Task<QuoteResult, Error>] = [:]

    // MARK: - Init

    init() {}

    // MARK: - Public API

    /// Fetch a live quote for the given symbol.
    ///
    /// **Object-lifetime guarantee (Issue 7 root-cause fix):**
    /// The `Task { [self] in … }` closure captures `self` strongly.
    /// This prevents the fetcher from being released while the network
    /// round-trip is in progress, regardless of what the owner does.
    ///
    /// Any previous in-flight fetch for the same symbol is cancelled before
    /// the new one is issued, so the returned result is always from the
    /// most-recent call.
    ///
    /// - Parameter symbol: The ticker symbol to fetch (e.g. `"AAPL"`).
    /// - Returns: A `QuoteResult` on success.
    /// - Throws: `FetchError` on any failure.
    func fetchQuote(for symbol: String) async throws -> QuoteResult {
        // Cancel any existing in-flight request for this symbol before
        // issuing a new one.  This prevents a stale callback from
        // overwriting the result of a fresher request.
        activeTasks[symbol]?.cancel()

        // Root-cause fix: capture `self` strongly ([self]) so the fetcher
        // object cannot be deallocated while the async network round-trip
        // is pending.  [weak self] would allow the fetcher to be released
        // mid-flight if the owner drops its reference, silently losing
        // the result.
        let task = Task<QuoteResult, Error> { [self] in
            try await self.performFetch(symbol: symbol)
        }

        activeTasks[symbol] = task

        do {
            let result = try await task.value
            activeTasks.removeValue(forKey: symbol)
            return result
        } catch {
            activeTasks.removeValue(forKey: symbol)
            throw error
        }
    }

    /// Cancel all in-flight fetch tasks.
    /// Call this when the owner is being torn down to avoid unnecessary
    /// network work and to release the strong-capture references promptly.
    func cancelAll() {
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
    }

    // MARK: - Private

    private func performFetch(symbol: String) async throws -> QuoteResult {
        let baseURL = AWCSecretConfig.shared.marketDataBaseURL
        guard !baseURL.isEmpty else {
            throw FetchError.missingBaseURL
        }

        let urlString = "\(baseURL)/quote/\(symbol)"
        guard let url = URL(string: urlString) else {
            throw FetchError.invalidURL(urlString)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            Self.log.error("MarketDataFetcher: network error for \(symbol) – \(error.localizedDescription)")
            throw FetchError.networkError(error)
        }

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw FetchError.badHTTPStatus(http.statusCode)
        }

        do {
            let envelope = try JSONDecoder().decode(QuoteEnvelope.self, from: data)
            let timestamp = envelope.t.map { Date(timeIntervalSince1970: $0) } ?? Date()
            let result = QuoteResult(symbol: symbol, price: envelope.price, timestamp: timestamp)
            Self.log.info("MarketDataFetcher: \(symbol) = \(result.price)")
            return result
        } catch {
            throw FetchError.decodingError(error)
        }
    }

    // MARK: - Decode envelope

    private struct QuoteEnvelope: Decodable {
        let price: Double
        let t: TimeInterval?
    }
}
