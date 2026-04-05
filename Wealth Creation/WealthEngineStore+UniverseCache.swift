import Foundation

// MARK: - WealthEngineStore+UniverseCache
//
// Optimizes recurring soft and deep refresh cycles by tracking whether the
// universe or market data has actually changed between cycles, so unnecessary
// scans are skipped.
//
// ── Strategy ─────────────────────────────────────────────────────────────
//
//   Universe
//   ────────
//   • Skip the universe re-download when both conditions hold:
//       1. A previous download was recorded within `universeMinRefreshInterval`
//          (6 hours).  Universe metadata changes infrequently; downloading
//          every 10 minutes wastes bandwidth when the data is stable.
//       2. The universe fingerprint (record count stored in UserDefaults)
//          matches the current `WealthMarketUniverseStore` record count.
//          A count mismatch means the store was updated externally (e.g.
//          hot-reload, region expansion) and a fresh download is warranted.
//   • On first launch (no stored timestamp) always downloads.
//
//   Cards (AI scan + market ranking)
//   ─────────────────────────────────
//   • Skip re-scoring when:
//       - The universe did NOT change in the current cycle, AND
//       - No IBKR market-data update has occurred since the last card
//         refresh pass.
//   • `recordMarketDataUpdated()` is called after every IBKR price sync so
//     the next soft/deep cycle re-scores cards with fresh prices.
//   • `recordCardsRefreshed()` is called after market ranking completes so
//     subsequent cycles can compare against this timestamp.
//
// ── UserDefaults keys ─────────────────────────────────────────────────────
//   awc_universe_signature       – Int  : last known universe record count
//   awc_universe_last_downloaded – Date : timestamp of last universe download
//   awc_market_data_last_updated – Date : timestamp of last IBKR price sync
//   awc_cards_last_refreshed     – Date : timestamp of last AI+market pass

private enum UniverseCacheKey {
    static let universeSignature      = "awc_universe_signature"
    static let universeLastDownloaded = "awc_universe_last_downloaded"
    static let marketDataLastUpdated  = "awc_market_data_last_updated"
    static let cardsLastRefreshed     = "awc_cards_last_refreshed"
}

extension WealthEngineStore {

    // MARK: - Universe freshness threshold

    /// Minimum time that must elapse before the universe is eligible for a
    /// re-download.  Universe data is global market metadata that changes
    /// infrequently; re-downloading every 10 minutes wastes bandwidth when
    /// the data is stable.
    var universeMinRefreshInterval: TimeInterval { 6 * 60 * 60 }  // 6 hours

    // MARK: - Universe change detection

    /// Returns `true` when the universe should be re-downloaded this cycle.
    ///
    /// A re-download is needed when ANY of these conditions is true:
    ///   1. No previous download timestamp exists (first launch / after reset).
    ///   2. `universeMinRefreshInterval` (6 h) has elapsed since the last download.
    ///   3. The universe fingerprint (record count) differs from the stored value,
    ///      meaning the store was updated externally since the last download.
    @MainActor
    func universeNeedsDownload() -> Bool {
        let defaults = UserDefaults.standard

        // Case 1: never downloaded before
        guard let lastDownloaded = defaults.object(
            forKey: UniverseCacheKey.universeLastDownloaded
        ) as? Date else {
            return true
        }

        // Case 2: minimum refresh interval has elapsed
        if Date().timeIntervalSince(lastDownloaded) >= universeMinRefreshInterval {
            return true
        }

        // Case 3: fingerprint (record count) has changed
        let storedCount  = defaults.integer(forKey: UniverseCacheKey.universeSignature)
        let currentCount = WealthMarketUniverseStore.shared.records.count
        return currentCount != storedCount
    }

    /// Record the outcome of a universe download and detect whether the
    /// universe actually changed.
    ///
    /// Saves the current `WealthMarketUniverseStore` record count and the
    /// current timestamp to UserDefaults.
    ///
    /// - Returns: `true` when the post-download record count differs from
    ///   the previously stored count (or no count was previously stored),
    ///   indicating that cards should be re-scored this cycle.
    @MainActor
    @discardableResult
    func recordUniverseDownloaded() -> Bool {
        let defaults     = UserDefaults.standard
        let storedCount  = defaults.integer(forKey: UniverseCacheKey.universeSignature)
        let currentCount = WealthMarketUniverseStore.shared.records.count
        let universeChanged = currentCount != storedCount || storedCount == 0

        defaults.set(Date(),         forKey: UniverseCacheKey.universeLastDownloaded)
        defaults.set(currentCount,   forKey: UniverseCacheKey.universeSignature)

        WealthEventLogStore.shared.record(
            title: "Universe Cache",
            detail: "Universe downloaded: \(currentCount) records" +
                    (universeChanged ? " (changed from \(storedCount))" : " (unchanged)"),
            category: "cache",
            tintName: universeChanged ? "green" : "blue",
            timestamp: .now
        )

        return universeChanged
    }

    // MARK: - Market data change detection

    /// Record that IBKR market data has been updated.
    ///
    /// Called after every IBKR price sync so the next soft/deep refresh
    /// cycle knows to re-score cards even if the universe has not changed.
    @MainActor
    func recordMarketDataUpdated() {
        UserDefaults.standard.set(Date(), forKey: UniverseCacheKey.marketDataLastUpdated)
    }

    // MARK: - Card refresh gate

    /// Returns `true` when the AI scan + market ranking passes should run.
    ///
    /// Cards need re-scoring when either:
    ///   - `universeChanged` is `true` (new universe data was just downloaded), OR
    ///   - IBKR market data was updated after the last card refresh pass.
    ///
    /// Always returns `true` on first run (no stored `cardsLastRefreshed`).
    @MainActor
    func cardsNeedRefresh(universeChanged: Bool) -> Bool {
        if universeChanged { return true }

        let defaults = UserDefaults.standard

        // First card refresh ever
        guard let cardsRefreshed = defaults.object(
            forKey: UniverseCacheKey.cardsLastRefreshed
        ) as? Date else {
            return true
        }

        // Market data updated since last card refresh
        if let marketUpdated = defaults.object(
            forKey: UniverseCacheKey.marketDataLastUpdated
        ) as? Date,
           marketUpdated > cardsRefreshed {
            return true
        }

        return false
    }

    /// Record that the card scoring pass (AI scan + market ranking) has completed.
    ///
    /// Saves the current timestamp so `cardsNeedRefresh(universeChanged:)` can
    /// compare it against the next IBKR market-data update timestamp.
    @MainActor
    func recordCardsRefreshed() {
        UserDefaults.standard.set(Date(), forKey: UniverseCacheKey.cardsLastRefreshed)

        WealthEventLogStore.shared.record(
            title: "Universe Cache",
            detail: "Cards refresh recorded (AI scan + market ranking complete).",
            category: "cache",
            tintName: "blue",
            timestamp: .now
        )
    }
}
