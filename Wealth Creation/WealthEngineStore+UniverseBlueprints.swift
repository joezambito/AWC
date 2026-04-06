import Foundation

// MARK: - WealthEngineStore+UniverseBlueprints
//
// Provides `currentUniverseSeedSource()` – the single point that returns
// the best available universe snapshot to the startup pipeline.
//
// ── Design ───────────────────────────────────────────────────────────────
//
//   Priority order:
//     1. Persisted cache  (WealthMarketUniverseStore, restored by
//                          prepareCachedSnapshotForStartup on a background
//                          thread before this method is called)
//     2. Empty            (no data yet – the async startup sequence will
//                          populate the store via reloadForStartupSequence)
//
// ── Why no synchronous CSV fallback? ─────────────────────────────────────
//
//   The previous implementation had a third case that called
//   `WealthMarketUniverseLoader.records()` when the persisted cache was
//   empty.  That call reads the entire 128 k-row global_universe.csv
//   synchronously on the main thread, which blocked the UI for minutes.
//
//   The proper async path already exists:
//     • `WealthMarketUniverseStore.prepareCachedSnapshotForStartup()`
//       restores from the on-device cache without blocking.
//     • `WealthMarketUniverseStore.reloadForStartupSequence()` loads the
//       CSV asynchronously in the background with staggered region updates.
//
//   Removing the synchronous fallback ensures:
//     ✅  App launches without freezing
//     ✅  UI shows cached data immediately (or empty gracefully)
//     ✅  CSV is loaded asynchronously via the startup sequence
//     ✅  No main-thread blocking
//
// Fixes:
//   Startup freeze – WealthMarketUniverseLoader.records() called on @MainActor

extension WealthEngineStore {

    // MARK: - Universe seed source

    /// Return the best available universe snapshot without blocking the main thread.
    ///
    /// Returns the persisted `WealthMarketUniverseStore` records when they
    /// are available, or an empty result otherwise.  The async startup
    /// sequence (`WealthMarketUniverseStore.reloadForStartupSequence()`)
    /// is responsible for loading the CSV and populating the store in the
    /// background.
    ///
    /// - Note: The synchronous `WealthMarketUniverseLoader.records()` fallback
    ///   has been intentionally removed.  It read the entire 128 k-row CSV on
    ///   the main thread and froze the app on every first launch or after a
    ///   cache clear.
    @MainActor
    static func currentUniverseSeedSource() -> (label: String, signature: String, records: [MarketUniverseRecord]) {
        let universeStore = WealthMarketUniverseStore.shared
        let persistedRecords = universeStore.records
        if !persistedRecords.isEmpty {
            return ("persisted", "persisted|\(persistedRecords.count)", persistedRecords)
        }

        // ✅ Return empty – the async startup sequence will load the CSV in
        //    the background via reloadForStartupSequence().
        return ("empty", "empty", [])
    }
}
