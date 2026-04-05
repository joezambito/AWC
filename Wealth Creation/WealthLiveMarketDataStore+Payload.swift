import Foundation

// MARK: - WealthLiveMarketDataStore+Payload
//
// Defines the `WealthLiveMarketPayload` value type and adds a
// `receive(_:)` entry-point to `WealthLiveMarketDataStore` so that
// inbound market-data packets can be decoded and applied to the store
// in a single, testable call.
//
// No existing properties or methods on `WealthLiveMarketDataStore`
// are modified.

// MARK: - Payload type

/// A single decoded packet of live market data for one instrument.
struct WealthLiveMarketPayload {
    /// Ticker symbol (e.g. "AAPL").
    let symbol:    String
    /// Last traded price.
    let lastPrice: Double
    /// Best bid price.
    let bid:       Double
    /// Best ask price.
    let ask:       Double
    /// Traded volume in the current session.
    let volume:    Int
    /// Server-side timestamp of the quote.
    let timestamp: Date
}

// MARK: - WealthLiveMarketDataStore extension

extension WealthLiveMarketDataStore {

    // MARK: - Payload ingestion

    /// Ingest a decoded live-market payload, updating the store's
    /// internal quote table and notifying downstream consumers.
    ///
    /// - Parameter payload: The decoded market-data packet to apply.
    func receive(_ payload: WealthLiveMarketPayload) {
        applyQuote(payload)

        WealthEventLogStore.shared.record(
            title: "Live Market Data",
            detail: "\(payload.symbol) last=\(payload.lastPrice) bid=\(payload.bid) ask=\(payload.ask) vol=\(payload.volume)",
            category: "market",
            tintName: "blue",
            timestamp: payload.timestamp
        )
    }

    /// Ingest a batch of payloads in one call.
    ///
    /// - Parameter payloads: An array of decoded market-data packets.
    func receiveBatch(_ payloads: [WealthLiveMarketPayload]) {
        for payload in payloads {
            applyQuote(payload)
        }

        WealthEventLogStore.shared.record(
            title: "Live Market Data",
            detail: "Batch received: \(payloads.count) quote(s).",
            category: "market",
            tintName: "blue",
            timestamp: .now
        )
    }
}
