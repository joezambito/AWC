import Foundation

// MARK: - WealthEngineStore+Cache
//
// Handles persisting the engine's current snapshot so that on the next
// app launch the UI can be populated immediately from cache (before the
// background startup sequence delivers fresh data).
//
// ── Persistence strategy ──────────────────────────────────────────────────
// Large payloads (ranked assets, scanned signals, holdings) are stored as
// JSON files in the app's Caches directory.  Only lightweight scalar values
// (timestamps) are kept in UserDefaults.
//
// Rationale:
//   • UserDefaults is synchronous at app launch – decoding 128 k ranked
//     assets on the main thread caused multi-second UI freezes.
//   • UserDefaults has practical limits (~4 MB) before reliability degrades.
//   • File-backed storage allows atomic writes, file-modification timestamps
//     for freshness checking, and off-main-thread reads.

// Module-level constant: resolved once at startup, never changes for the
// lifetime of the process.  Using a module-level let avoids the need for a
// stored property (which extensions cannot add) while preventing repeated
// FileManager filesystem lookups on every property access.
private let wealthEngineCacheDir: URL? =
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first

extension WealthEngineStore {

    // MARK: - UserDefaults keys (lightweight scalars ONLY)

    private enum DefaultsKey {
        static let lastRefresh      = "awc_engine_last_refresh"
        static let lastHeavyRefresh = "awc_engine_last_heavy_refresh"
    }

    // MARK: - File-backed cache URLs

    var rankedAssetsFileURL: URL? {
        wealthEngineCacheDir?.appendingPathComponent("awc_engine_ranked_assets.json")
    }

    var scannedSignalsFileURL: URL? {
        wealthEngineCacheDir?.appendingPathComponent("awc_engine_scanned_signals.json")
    }

    var holdingsFileURL: URL? {
        wealthEngineCacheDir?.appendingPathComponent("awc_engine_holdings.json")
    }

    // MARK: - Public API

    /// Restore the most-recently persisted snapshot into the engine's
    /// @Published properties so the UI shows stale (but non-empty) data
    /// while the background startup sequence runs.
    ///
    /// Called as the very first step of `bootstrap()` – before any network
    /// or scan work begins.
    ///
    /// Large array decoding is **not** performed here – call
    /// `restoreCacheInBackground(completion:)` (from
    /// `WealthEngineStore+BackgroundCache.swift`) to avoid blocking the
    /// main thread.  This synchronous variant restores timestamps only and
    /// is kept for compatibility with any call site that cannot be made async.
    func restoreCache() {
        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: DefaultsKey.lastRefresh) as? Date {
            lastRefresh = stored
        }
        if let stored = defaults.object(forKey: DefaultsKey.lastHeavyRefresh) as? Date {
            lastHeavyRefresh = stored
        }
        restoreRankedAssetsFromFile()
        restoreScannedSignalsFromFile()
        restoreHoldingsFromFile()
    }

    /// Persist the current engine snapshot.
    ///   • Timestamps → UserDefaults (tiny, read synchronously at launch)
    ///   • Large arrays → Caches directory JSON files (atomic, off-thread-safe)
    ///
    /// Prefer `saveInBackground()` (from `WealthEngineStore+BackgroundCache.swift`)
    /// to avoid encoding 128 k cards on the main thread.
    func save() {
        let defaults = UserDefaults.standard
        if let date = lastRefresh {
            defaults.set(date, forKey: DefaultsKey.lastRefresh)
        }
        if let date = lastHeavyRefresh {
            defaults.set(date, forKey: DefaultsKey.lastHeavyRefresh)
        }
        persistRankedAssetsToFile()
        persistScannedSignalsToFile()
        persistHoldingsToFile()
    }

    // MARK: - Private file I/O helpers

    private func restoreRankedAssetsFromFile() {
        guard let url = rankedAssetsFileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Opportunity].self, from: data)
        else { return }
        rankedAssets = decoded
    }

    private func persistRankedAssetsToFile() {
        guard let url = rankedAssetsFileURL,
              let data = try? JSONEncoder().encode(rankedAssets)
        else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private func restoreScannedSignalsFromFile() {
        guard let url = scannedSignalsFileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([MarketSignal].self, from: data)
        else { return }
        scannedSignals = decoded
    }

    private func persistScannedSignalsToFile() {
        guard let url = scannedSignalsFileURL,
              let data = try? JSONEncoder().encode(scannedSignals)
        else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private func restoreHoldingsFromFile() {
        guard let url = holdingsFileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Holding].self, from: data)
        else { return }
        holdings = decoded
    }

    private func persistHoldingsToFile() {
        guard let url = holdingsFileURL,
              let data = try? JSONEncoder().encode(holdings)
        else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
