import Foundation

// MARK: - WealthEngineStore+BackgroundCache
//
// NEW extension – does NOT modify any functions in WealthEngineStore+Cache.swift.
//
// Problem addressed:
//   `restoreCache()` (defined in WealthEngineStore+Cache.swift) performs
//   JSON decoding on the main thread.  When the ranked-assets file contains
//   128 k cards the decode takes several seconds, blocking tab navigation
//   and causing the observed 5-second+ UI freeze on launch.
//
// Solution (new code only):
//   `restoreCacheInBackground(completion:)` performs all file I/O and JSON
//   decoding on a detached background task so the main thread is free
//   throughout.  Only the final @Published property assignments hop back
//   to the @MainActor, keeping each hop as lightweight as possible.
//
//   `saveInBackground()` encodes and writes large arrays on a background
//   task, preventing encoding 128 k cards from blocking the UI during a
//   save cycle.  Timestamps are written to UserDefaults synchronously on
//   the same background task (they are tiny and thread-safe).
//
// Fixes:
//   Error #7 – UI Thread Fix (heavy JSON decode / encode off main thread)

extension WealthEngineStore {

    // MARK: - Background cache restore

    /// Restore the most-recently persisted snapshot into the engine's
    /// @Published properties **without blocking the main thread**.
    ///
    /// All file I/O and JSON decoding runs on a detached background task.
    /// Only the final property assignments hop back to the @MainActor.
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

            // Restore lightweight scalars (still in UserDefaults)
            let lastRefreshDate      = defaults.object(forKey: "awc_engine_last_refresh")      as? Date
            let lastHeavyRefreshDate = defaults.object(forKey: "awc_engine_last_heavy_refresh") as? Date

            // Decode large arrays from file-backed cache (off main thread)
            var restoredAssets:   [Opportunity]?
            var restoredSignals:  [MarketSignal]?
            var restoredHoldings: [Holding]?

            let fm = FileManager.default
            let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first

            if let url = cacheDir?.appendingPathComponent("awc_engine_ranked_assets.json"),
               let data = try? Data(contentsOf: url) {
                restoredAssets = try? JSONDecoder().decode([Opportunity].self, from: data)
            }
            if let url = cacheDir?.appendingPathComponent("awc_engine_scanned_signals.json"),
               let data = try? Data(contentsOf: url) {
                restoredSignals = try? JSONDecoder().decode([MarketSignal].self, from: data)
            }
            if let url = cacheDir?.appendingPathComponent("awc_engine_holdings.json"),
               let data = try? Data(contentsOf: url) {
                restoredHoldings = try? JSONDecoder().decode([Holding].self, from: data)
            }

            // Lightweight assignment on the main actor
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

    /// Persist the current engine snapshot **without blocking the main thread**.
    ///
    /// Timestamps are written to UserDefaults and large arrays are JSON-
    /// encoded and written to file-backed storage – all on a background task.
    func saveInBackground() {
        // Capture value copies before leaving the main actor.
        let capturedAssets        = rankedAssets
        let capturedSignals       = scannedSignals
        let capturedHoldings      = holdings
        let capturedRefresh       = lastRefresh
        let capturedHeavyRefresh  = lastHeavyRefresh

        Task.detached(priority: .utility) {
            let defaults = UserDefaults.standard
            let fm       = FileManager.default
            let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first

            // Lightweight timestamps → UserDefaults
            if let date = capturedRefresh {
                defaults.set(date, forKey: "awc_engine_last_refresh")
            }
            if let date = capturedHeavyRefresh {
                defaults.set(date, forKey: "awc_engine_last_heavy_refresh")
            }

            // Large arrays → file-backed (atomic write)
            if let url  = cacheDir?.appendingPathComponent("awc_engine_ranked_assets.json"),
               let data = try? JSONEncoder().encode(capturedAssets) {
                try? data.write(to: url, options: [.atomic])
            }
            if let url  = cacheDir?.appendingPathComponent("awc_engine_scanned_signals.json"),
               let data = try? JSONEncoder().encode(capturedSignals) {
                try? data.write(to: url, options: [.atomic])
            }
            if let url  = cacheDir?.appendingPathComponent("awc_engine_holdings.json"),
               let data = try? JSONEncoder().encode(capturedHoldings) {
                try? data.write(to: url, options: [.atomic])
            }
        }
    }
}
