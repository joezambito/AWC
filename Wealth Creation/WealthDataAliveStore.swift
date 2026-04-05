import Foundation

// MARK: - WealthDataAliveStore
//
// Tracks whether each data layer is "alive" — i.e. has produced a
// successful update within its expected refresh window.
//
// ROOT-CAUSE FIX — Universe persistence:
//   Previously `lastUniverseDownload` was stored in memory only, so it was
//   nil on every app restart.  `isUniverseAlive` therefore always returned
//   false, causing `runUniverseScan()` to download the full 128 k-row
//   universe on every timer tick (every 10 / 20 / 30 min).
//
//   Fix: `lastUniverseDownload` is now backed by UserDefaults under the key
//   `awc_universe_last_downloaded` — the same key that
//   `WealthMarketUniverseStore.reloadForStartupSequence()` writes.  A single
//   source of truth is shared between the startup cache check and the
//   alive-store, so `isUniverseAlive` is correct immediately after any cold
//   launch without requiring additional startup-sequence logic.
//
// Data layers tracked:
//   • Market data   (expected every 10 min during trading hours)
//   • Universe data (expected every 6 h  — persisted across restarts)
//   • AI scores     (expected after every deep refresh)
//   • Holdings      (expected after every IBKR sync)

@MainActor
final class WealthDataAliveStore: ObservableObject {

    // MARK: Shared instance

    static let shared = WealthDataAliveStore()

    // MARK: - UserDefaults key for universe freshness
    //
    // Must match the key written by
    // WealthMarketUniverseStore.reloadForStartupSequence() so both the
    // startup cache-check and this store read from the same timestamp.

    static let universeDownloadDefaultsKey = "awc_universe_last_downloaded"

    // MARK: - Freshness thresholds

    private let marketDataMaxAge:   TimeInterval = 10 * 60    // 10 min
    let          universeDataMaxAge: TimeInterval = 6  * 3600  //  6 h
    private let aiScoresMaxAge:     TimeInterval = 30 * 60    // 30 min
    private let holdingsMaxAge:     TimeInterval = 15 * 60    // 15 min

    // MARK: - Timestamps

    @Published private(set) var lastMarketDataUpdate: Date?
    /// Persisted to UserDefaults so `isUniverseAlive` survives app restarts.
    @Published private(set) var lastUniverseDownload: Date?
    @Published private(set) var lastAIScoreUpdate:    Date?
    @Published private(set) var lastHoldingsSync:     Date?

    // MARK: - Init

    private init() {
        // Restore universe timestamp from UserDefaults on every launch so
        // isUniverseAlive is accurate before any new download is attempted.
        lastUniverseDownload =
            UserDefaults.standard.object(
                forKey: Self.universeDownloadDefaultsKey
            ) as? Date
    }

    // MARK: - Public update API

    func recordMarketDataUpdate() { lastMarketDataUpdate = Date() }

    /// Record a successful universe download.
    /// Writes to UserDefaults so the timestamp survives app restarts and
    /// `isUniverseAlive` stays true across cold launches within the 6 h window.
    func recordUniverseDownload() {
        let now = Date()
        lastUniverseDownload = now
        UserDefaults.standard.set(now, forKey: Self.universeDownloadDefaultsKey)
    }

    func recordAIScoreUpdate() { lastAIScoreUpdate = Date() }
    func recordHoldingsSync()  { lastHoldingsSync  = Date() }

    // MARK: - Alive queries

    var isMarketDataAlive: Bool {
        guard let t = lastMarketDataUpdate else { return false }
        return Date().timeIntervalSince(t) <= marketDataMaxAge
    }

    /// Returns `true` when the universe was last downloaded within 6 hours.
    /// Reads from UserDefaults directly to cover the case where the process
    /// just launched and `lastUniverseDownload` hasn't been set in-memory yet
    /// (e.g. WealthMarketUniverseStore wrote the key before init ran).
    var isUniverseAlive: Bool {
        let stored = (UserDefaults.standard.object(
                          forKey: Self.universeDownloadDefaultsKey
                      ) as? Date) ?? lastUniverseDownload
        guard let t = stored else { return false }
        return Date().timeIntervalSince(t) <= universeDataMaxAge
    }

    var isAIScoresAlive: Bool {
        guard let t = lastAIScoreUpdate else { return false }
        return Date().timeIntervalSince(t) <= aiScoresMaxAge
    }

    var isHoldingsAlive: Bool {
        guard let t = lastHoldingsSync else { return false }
        return Date().timeIntervalSince(t) <= holdingsMaxAge
    }

    var isFullyAlive: Bool {
        isMarketDataAlive && isUniverseAlive && isAIScoresAlive && isHoldingsAlive
    }

    // MARK: - Diagnostics

    func logAliveStatus() {
        WealthEventLogStore.shared.record(
            title: "Data Alive Store",
            detail: "market=\(isMarketDataAlive) | universe=\(isUniverseAlive) | ai=\(isAIScoresAlive) | holdings=\(isHoldingsAlive)",
            category: "engine",
            tintName: isFullyAlive ? "green" : "orange",
            timestamp: .now
        )
    }

    // MARK: - Reset

    /// Reset all timestamps.  Clears the UserDefaults universe key so the
    /// next launch forces a fresh universe download.
    func reset() {
        lastMarketDataUpdate = nil
        lastUniverseDownload = nil
        lastAIScoreUpdate    = nil
        lastHoldingsSync     = nil
        UserDefaults.standard.removeObject(forKey: Self.universeDownloadDefaultsKey)
    }
}
