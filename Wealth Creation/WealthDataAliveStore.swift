import Foundation

// MARK: - WealthDataAliveStore
//
// Tracks whether each data layer is "alive" — i.e. has produced a
// successful update within its expected refresh window.
//
// The engine has several independently-refreshed data layers:
//   • Market data   (expected every 10 min during trading hours)
//   • Universe data (expected every 6 h)
//   • AI scores     (expected after every deep refresh)
//   • Holdings      (expected after every IBKR sync)
//
// `WealthDataAliveStore` provides a single query point for views and
// the audit layer to check which layers are current without duplicating
// threshold logic across the codebase.
//
// No existing engine logic, functions, or behaviors are changed.

@MainActor
final class WealthDataAliveStore: ObservableObject {

    // MARK: Shared instance

    static let shared = WealthDataAliveStore()
    private init() {}

    // MARK: - Freshness thresholds

    private let marketDataMaxAge:   TimeInterval = 10 * 60    // 10 min
    private let universeDataMaxAge: TimeInterval = 6  * 3600  //  6 h
    private let aiScoresMaxAge:     TimeInterval = 30 * 60    // 30 min
    private let holdingsMaxAge:     TimeInterval = 15 * 60    // 15 min

    // MARK: - Timestamps (updated by the engine after each successful pass)

    @Published private(set) var lastMarketDataUpdate:   Date?
    @Published private(set) var lastUniverseDownload:   Date?
    @Published private(set) var lastAIScoreUpdate:      Date?
    @Published private(set) var lastHoldingsSync:       Date?

    // MARK: - Public update API

    func recordMarketDataUpdate()   { lastMarketDataUpdate   = Date() }
    func recordUniverseDownload()   { lastUniverseDownload   = Date() }
    func recordAIScoreUpdate()      { lastAIScoreUpdate      = Date() }
    func recordHoldingsSync()       { lastHoldingsSync       = Date() }

    // MARK: - Alive queries

    /// `true` when market-data was updated within the last `marketDataMaxAge`.
    var isMarketDataAlive: Bool {
        guard let t = lastMarketDataUpdate else { return false }
        return Date().timeIntervalSince(t) <= marketDataMaxAge
    }

    /// `true` when the universe was downloaded within the last `universeDataMaxAge`.
    var isUniverseAlive: Bool {
        guard let t = lastUniverseDownload else { return false }
        return Date().timeIntervalSince(t) <= universeDataMaxAge
    }

    /// `true` when AI scores were updated within the last `aiScoresMaxAge`.
    var isAIScoresAlive: Bool {
        guard let t = lastAIScoreUpdate else { return false }
        return Date().timeIntervalSince(t) <= aiScoresMaxAge
    }

    /// `true` when holdings were synced within the last `holdingsMaxAge`.
    var isHoldingsAlive: Bool {
        guard let t = lastHoldingsSync else { return false }
        return Date().timeIntervalSince(t) <= holdingsMaxAge
    }

    /// `true` when all data layers are alive.
    var isFullyAlive: Bool {
        isMarketDataAlive && isUniverseAlive && isAIScoresAlive && isHoldingsAlive
    }

    // MARK: - Diagnostics

    /// Log a snapshot of all alive-states to the event log.
    func logAliveStatus() {
        WealthEventLogStore.shared.record(
            title: "Data Alive Store",
            detail: "market=\(isMarketDataAlive) | universe=\(isUniverseAlive) | ai=\(isAIScoresAlive) | holdings=\(isHoldingsAlive)",
            category: "engine",
            tintName: isFullyAlive ? "green" : "orange",
            timestamp: .now
        )
    }

    /// Reset all timestamps (e.g. on factory reset or sign-out).
    func reset() {
        lastMarketDataUpdate = nil
        lastUniverseDownload = nil
        lastAIScoreUpdate    = nil
        lastHoldingsSync     = nil
    }
}
