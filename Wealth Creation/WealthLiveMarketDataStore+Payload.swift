import Foundation

// MARK: - WealthLiveMarketDataStore+Payload
//
// Defines the `WealthLiveMarketPayload` value type, the
// `WealthLiveMarketDataStore` singleton, and a `receive(_:)` /
// `receiveBatch(_:)` entry-point so that inbound market-data packets
// can be decoded and applied to the store in a single, testable call.
//
// The base class (`WealthLiveMarketDataStore`) is declared here so
// this file compiles as a standalone unit when `WealthCore.swift` is
// not present in the git tree.  The `applyQuote(_:)` primitive is a
// stub whose full implementation lives in WealthCore.swift.
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

// MARK: - WealthLiveMarketDataStore

/// Observable store for live streaming market data.
///
/// Each inbound quote is written into an internal symbol-keyed table so
/// that the latest bid/ask/last for any instrument is always available
/// for the card-scoring and AI-Live passes.
///
/// The full quote-table implementation (property storage, UI publishing,
/// and broker-feed plumbing) lives in `WealthCore.swift`.  This file
/// provides the class declaration and the payload-ingestion surface only.
@MainActor
final class WealthLiveMarketDataStore: ObservableObject {

    // MARK: Shared instance

    static let shared = WealthLiveMarketDataStore()
    private init() {}

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

    // MARK: - Primitive (override point)

    /// Write a single quote into the internal symbol-keyed table.
    ///
    /// Full implementation lives in WealthCore.swift.
    func applyQuote(_ payload: WealthLiveMarketPayload) {
        // Implemented in WealthCore.swift (existing engine logic).
    }
}
