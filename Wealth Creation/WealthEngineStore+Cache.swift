import Foundation
import OSLog

// MARK: - WealthEngineStore+Cache
//
// REPLACEMENT FILE – Issue 6 root-cause fix.
//
// Root cause: the previous implementation wrote rankedAssets, scannedSignals,
// and holdings as three separate files in sequence.  If the process was
// interrupted between any two writes the on-disk snapshot could contain a mix
// of old and new data.  Using `.atomic` on each individual write fixed
// single-file corruption but did NOT fix the multi-file consistency window.
//
// Fix: all engine state is now persisted as a single `EngineStateBundle`
// through `PersistenceManager.shared.saveBundle(_:)`, which performs ONE
// atomic write.  Either the full snapshot is committed or the original file
// is left intact — there is no partial-state window.
//
// Behaviour change: three separate cache files are replaced by one bundle
// file (`awc_engine_state_bundle.json`).  A legacy-fallback path reads the
// old files if the bundle is absent so existing installs are not data-wiped
// on the first upgrade.

private let wealthEngineCacheLog = Logger(subsystem: "com.awg.wealth", category: "EngineCache")

// MARK: - Legacy file URLs (migration fallback only)
//
// These URLs are used exclusively inside `restoreCache()` when the new bundle
// file does not yet exist.  Once the bundle file is written on the first
// `save()` call the legacy files are no longer consulted.

private let wealthEngineCacheDir: URL? =
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first

extension WealthEngineStore {

    // MARK: - Legacy UserDefaults keys (migration fallback only)

    private enum LegacyDefaultsKey {
        static let lastRefresh      = "awc_engine_last_refresh"
        static let lastHeavyRefresh = "awc_engine_last_heavy_refresh"
    }

    // MARK: - Legacy file URLs (migration fallback only)

    private var legacyRankedAssetsURL: URL? {
        wealthEngineCacheDir?.appendingPathComponent("awc_engine_ranked_assets.json")
    }

    private var legacyScannedSignalsURL: URL? {
        wealthEngineCacheDir?.appendingPathComponent("awc_engine_scanned_signals.json")
    }

    private var legacyHoldingsURL: URL? {
        wealthEngineCacheDir?.appendingPathComponent("awc_engine_holdings.json")
    }

    // MARK: - Public API

    /// Restore the most-recently persisted snapshot into the engine's
    /// @Published properties so the UI shows stale (but non-empty) data
    /// while the background startup sequence runs.
    ///
    /// Reads from the atomic bundle file (Issue 6 root-cause fix).
    /// Falls back to legacy individual files if the bundle does not yet
    /// exist (migration path for existing installs).
    ///
    /// Prefer `restoreCacheInBackground(completion:)` (BackgroundCache
    /// extension) to avoid decoding large arrays on the main thread.
    func restoreCache() {
        if let bundle = PersistenceManager.shared.loadBundle() {
            applyBundle(bundle)
            wealthEngineCacheLog.info("restoreCache: restored from atomic bundle.")
        } else {
            restoreFromLegacyFiles()
        }
    }

    /// Persist the current engine snapshot as a single atomic bundle.
    ///
    /// The bundle write is the Issue 6 root-cause fix: all arrays and
    /// timestamps are encoded together and written in one atomic operation
    /// so there is no window in which a partial state can be on disk.
    ///
    /// Prefer `saveInBackground()` (BackgroundCache extension) to avoid
    /// encoding large arrays on the main thread.
    func save() {
        let bundle = EngineStateBundle(
            rankedAssets:     rankedAssets,
            scannedSignals:   scannedSignals,
            holdings:         holdings,
            lastRefresh:      lastRefresh,
            lastHeavyRefresh: lastHeavyRefresh
        )
        PersistenceManager.shared.saveBundle(bundle)
    }

    // MARK: - Private helpers

    /// Apply a decoded bundle to the engine's @Published properties.
    private func applyBundle(_ bundle: EngineStateBundle) {
        rankedAssets    = bundle.rankedAssets
        scannedSignals  = bundle.scannedSignals
        holdings        = bundle.holdings
        lastRefresh     = bundle.lastRefresh
        lastHeavyRefresh = bundle.lastHeavyRefresh
    }

    /// Legacy restore path: read the three separate files that existed
    /// before the atomic-bundle migration.  Also reads timestamps from
    /// UserDefaults (the old storage location).
    ///
    /// Called only when `PersistenceManager.shared.loadBundle()` returns nil.
    private func restoreFromLegacyFiles() {
        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: LegacyDefaultsKey.lastRefresh) as? Date {
            lastRefresh = stored
        }
        if let stored = defaults.object(forKey: LegacyDefaultsKey.lastHeavyRefresh) as? Date {
            lastHeavyRefresh = stored
        }
        if let url = legacyRankedAssetsURL,
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Opportunity].self, from: data) {
            rankedAssets = decoded
        }
        if let url = legacyScannedSignalsURL,
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([MarketSignal].self, from: data) {
            scannedSignals = decoded
        }
        if let url = legacyHoldingsURL,
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Holding].self, from: data) {
            holdings = decoded
        }
        wealthEngineCacheLog.info("restoreCache: restored from legacy individual files (migration path).")
    }
}
