import Foundation
import OSLog

// MARK: - WealthEngineStore+BackgroundCache
//
// REPLACEMENT FILE – Issue 6 root-cause fix (background path).
//
// Problem addressed (original):
//   `restoreCache()` decoded large JSON arrays on the main thread, causing
//   multi-second UI freezes on launch.
//
// Root-cause fix (Issue 6):
//   The background save/restore paths now delegate to
//   `PersistenceManager.shared.saveBundle(_:)` and
//   `PersistenceManager.shared.loadBundle()` so that all engine state is
//   written and read as a single atomic unit.  This removes the multi-file
//   consistency window that existed when three separate files were written
//   in sequence.
//
//   • `restoreCacheInBackground(completion:)` — all file I/O and JSON
//     decoding runs on a detached background task.  Only the final
//     @Published property assignments hop back to the @MainActor.
//   • `saveInBackground()` — encoding and the atomic write run on a
//     background task so encoding 128 k cards never blocks the UI.

private let wealthEngineBackgroundCacheLog =
    Logger(subsystem: "com.awg.wealth", category: "EngineBackgroundCache")

extension WealthEngineStore {

    // MARK: - Background cache restore

    /// Restore the most-recently persisted snapshot into the engine's
    /// @Published properties **without blocking the main thread**.
    ///
    /// All file I/O and JSON decoding runs on a detached background task.
    /// The engine state is read as a single atomic bundle so there is no
    /// risk of restoring a mix of old and new data (Issue 6 root-cause fix).
    ///
    /// Falls back to the legacy three-file format when the bundle file does
    /// not yet exist (migration path for existing installs).
    ///
    /// - Parameter completion: Called on the main actor once the restore
    ///   completes.  Use this to trigger downstream work (e.g. begin the
    ///   startup sequence).
    func restoreCacheInBackground(
        completion: @MainActor @Sendable @escaping () -> Void = {}
    ) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // Try the new atomic bundle first.
            if let bundle = PersistenceManager.shared.loadBundle() {
                await MainActor.run {
                    self.rankedAssets     = bundle.rankedAssets
                    self.scannedSignals   = bundle.scannedSignals
                    self.holdings         = bundle.holdings
                    self.lastRefresh      = bundle.lastRefresh
                    self.lastHeavyRefresh = bundle.lastHeavyRefresh

                    wealthEngineBackgroundCacheLog.info(
                        "restoreCacheInBackground: restored \(bundle.rankedAssets.count) assets " +
                        "from atomic bundle (off main thread)."
                    )
                    WealthEventLogStore.shared.record(
                        title: "Background Cache Restore",
                        detail: "Restored \(bundle.rankedAssets.count) ranked assets from atomic bundle (off main thread).",
                        category: "cache",
                        tintName: "blue",
                        timestamp: .now
                    )
                    completion()
                }
                return
            }

            // Migration fallback: no bundle yet; read the three legacy files.
            let fm       = FileManager.default
            let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first

            let defaults              = UserDefaults.standard
            let lastRefreshDate       = defaults.object(forKey: "awc_engine_last_refresh")      as? Date
            let lastHeavyRefreshDate  = defaults.object(forKey: "awc_engine_last_heavy_refresh") as? Date

            var restoredAssets:   [Opportunity]?
            var restoredSignals:  [MarketSignal]?
            var restoredHoldings: [Holding]?

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

            await MainActor.run {
                if let date = lastRefreshDate      { self.lastRefresh      = date }
                if let date = lastHeavyRefreshDate { self.lastHeavyRefresh = date }
                if let assets   = restoredAssets   { self.rankedAssets    = assets   }
                if let signals  = restoredSignals  { self.scannedSignals  = signals  }
                if let holdings = restoredHoldings { self.holdings        = holdings }

                wealthEngineBackgroundCacheLog.info(
                    "restoreCacheInBackground: restored \(restoredAssets?.count ?? 0) assets " +
                    "from legacy files (migration path, off main thread)."
                )
                WealthEventLogStore.shared.record(
                    title: "Background Cache Restore",
                    detail: "Restored \(restoredAssets?.count ?? 0) ranked assets via legacy path (off main thread).",
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
    /// All encoding and the atomic bundle write run on a background task.
    /// Writing a single bundle instead of three separate files is the
    /// Issue 6 root-cause fix: there is no window between writes in which
    /// a partial state can be on disk.
    func saveInBackground() {
        // Capture value copies before leaving the main actor.
        let capturedAssets       = rankedAssets
        let capturedSignals      = scannedSignals
        let capturedHoldings     = holdings
        let capturedRefresh      = lastRefresh
        let capturedHeavyRefresh = lastHeavyRefresh

        Task.detached(priority: .utility) {
            let bundle = EngineStateBundle(
                rankedAssets:     capturedAssets,
                scannedSignals:   capturedSignals,
                holdings:         capturedHoldings,
                lastRefresh:      capturedRefresh,
                lastHeavyRefresh: capturedHeavyRefresh
            )
            PersistenceManager.shared.saveBundle(bundle)
        }
    }
}
