import Foundation

// MARK: - WealthEngineStore+BackgroundCache
//
// NEW extension – does NOT modify any functions in WealthEngineStore+Cache.swift.
//
// Problem addressed:
//   `restoreCache()` (defined in WealthEngineStore+Cache.swift) is a
//   synchronous @MainActor function.  When it decodes a 128 k-card JSON blob
//   from UserDefaults it runs entirely on the main thread, blocking tab
//   navigation and causing the observed 5-minute UI freeze.
//
// Solution (new code only):
//   `restoreCacheInBackground(completion:)` performs all JSON decoding on a
//   detached background task so the main thread is free throughout.  Only the
//   final @Published property assignments are dispatched back to the
//   @MainActor, keeping each hop as lightweight as possible.
//
// Fixes:
//   Error #7 – UI Thread Fix (heavy JSON decode off main thread)

private enum BackgroundCacheKey {
    // Mirror of WealthEngineStore+Cache.swift CacheKey constants.
    // Duplicated here because the originals are file-private.
    static let lastRefresh      = "awc_engine_last_refresh"
    static let lastHeavyRefresh = "awc_engine_last_heavy_refresh"
    static let rankedAssetsData = "awc_engine_ranked_assets"
    static let scannedSignals   = "awc_engine_scanned_signals"
    static let holdingsData     = "awc_engine_holdings"
}

extension WealthEngineStore {

    // MARK: - Background cache restore

    /// Restore the most-recently persisted snapshot into the engine's
    /// @Published properties **without blocking the main thread**.
    ///
    /// All JSON decoding runs on a detached background task.  Only the
    /// final property assignments hop back to the @MainActor.
    ///
    /// - Parameter completion: An optional closure called on the main actor
    ///   once the restore is complete.  Use this to trigger downstream work
    ///   (e.g. begin the startup sequence) so it starts only after the cache
    ///   is present.
    func restoreCacheInBackground(
        completion: @MainActor @Sendable @escaping () -> Void = {}
    ) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let defaults = UserDefaults.standard

            // Decode everything on the background thread ─────────────────
            let lastRefreshDate      = defaults.object(forKey: BackgroundCacheKey.lastRefresh)      as? Date
            let lastHeavyRefreshDate = defaults.object(forKey: BackgroundCacheKey.lastHeavyRefresh) as? Date

            var restoredAssets:   [Opportunity]?
            var restoredSignals:  [MarketSignal]?
            var restoredHoldings: [Holding]?

            if let data = defaults.data(forKey: BackgroundCacheKey.rankedAssetsData) {
                restoredAssets = try? JSONDecoder().decode([Opportunity].self, from: data)
            }
            if let data = defaults.data(forKey: BackgroundCacheKey.scannedSignals) {
                restoredSignals = try? JSONDecoder().decode([MarketSignal].self, from: data)
            }
            if let data = defaults.data(forKey: BackgroundCacheKey.holdingsData) {
                restoredHoldings = try? JSONDecoder().decode([Holding].self, from: data)
            }

            // Lightweight assignment on the main actor ───────────────────
            await MainActor.run {
                if let date = lastRefreshDate      { self.lastRefresh      = date }
                if let date = lastHeavyRefreshDate { self.lastHeavyRefresh = date }
                if let assets   = restoredAssets   { self.rankedAssets    = assets   }
                if let signals  = restoredSignals  { self.scannedSignals  = signals  }
                if let holdings = restoredHoldings { self.holdings        = holdings }

                WealthEventLogStore.shared.record(
                    title: "Background Cache Restore",
                    detail: "Restored \(restoredAssets?.count ?? 0) ranked assets off main thread",
                    category: "cache",
                    tintName: "blue",
                    timestamp: .now
                )

                completion()
            }
        }
    }

    // MARK: - Background cache save

    /// Persist the current engine snapshot to UserDefaults **without
    /// blocking the main thread**.
    ///
    /// All JSON encoding runs on a detached background task, preventing
    /// the encode of 128 k cards from stalling the UI during a save cycle.
    func saveInBackground() {
        // Capture value copies before leaving the main actor.
        let capturedAssets        = rankedAssets
        let capturedSignals       = scannedSignals
        let capturedHoldings      = holdings
        let capturedRefresh       = lastRefresh
        let capturedHeavyRefresh  = lastHeavyRefresh

        Task.detached(priority: .utility) {
            let defaults = UserDefaults.standard

            if let date = capturedRefresh {
                defaults.set(date, forKey: BackgroundCacheKey.lastRefresh)
            }
            if let date = capturedHeavyRefresh {
                defaults.set(date, forKey: BackgroundCacheKey.lastHeavyRefresh)
            }
            if let data = try? JSONEncoder().encode(capturedAssets) {
                defaults.set(data, forKey: BackgroundCacheKey.rankedAssetsData)
            }
            if let data = try? JSONEncoder().encode(capturedSignals) {
                defaults.set(data, forKey: BackgroundCacheKey.scannedSignals)
            }
            if let data = try? JSONEncoder().encode(capturedHoldings) {
                defaults.set(data, forKey: BackgroundCacheKey.holdingsData)
            }
        }
    }
}
