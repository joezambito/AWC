import Foundation

// MARK: - WealthEngineStore+Cache
//
// Handles persisting the engine's current snapshot so that on the next
// app launch the UI can be populated immediately from cache (before the
// background startup sequence delivers fresh data).

extension WealthEngineStore {

    // MARK: - Cache storage keys

    private enum CacheKey {
        static let lastRefresh      = "awc_engine_last_refresh"
        static let lastHeavyRefresh = "awc_engine_last_heavy_refresh"
        static let rankedAssetsData = "awc_engine_ranked_assets"
        static let scannedSignals   = "awc_engine_scanned_signals"
        static let holdingsData     = "awc_engine_holdings"
    }

    // MARK: - Public API

    /// Restore the most-recently persisted snapshot into the engine's
    /// @Published properties so the UI shows stale (but non-empty) data
    /// while the background startup sequence runs.
    ///
    /// Called as the very first step of `bootstrap()` – before any network
    /// or scan work begins.
    func restoreCache() {
        let defaults = UserDefaults.standard

        if let stored = defaults.object(forKey: CacheKey.lastRefresh) as? Date {
            lastRefresh = stored
        }
        if let stored = defaults.object(forKey: CacheKey.lastHeavyRefresh) as? Date {
            lastHeavyRefresh = stored
        }

        restoreRankedAssets(from: defaults)
        restoreScannedSignals(from: defaults)
        restoreHoldings(from: defaults)
    }

    /// Persist the current engine snapshot to `UserDefaults`.
    /// Call after any scan phase that produces meaningful state changes.
    func save() {
        let defaults = UserDefaults.standard

        if let date = lastRefresh {
            defaults.set(date, forKey: CacheKey.lastRefresh)
        }
        if let date = lastHeavyRefresh {
            defaults.set(date, forKey: CacheKey.lastHeavyRefresh)
        }

        persistRankedAssets(to: defaults)
        persistScannedSignals(to: defaults)
        persistHoldings(to: defaults)
    }

    // MARK: - Private helpers

    private func restoreRankedAssets(from defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: CacheKey.rankedAssetsData),
            let decoded = try? JSONDecoder().decode([Opportunity].self, from: data)
        else { return }
        rankedAssets = decoded
    }

    private func persistRankedAssets(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(rankedAssets) else { return }
        defaults.set(data, forKey: CacheKey.rankedAssetsData)
    }

    private func restoreScannedSignals(from defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: CacheKey.scannedSignals),
            let decoded = try? JSONDecoder().decode([MarketSignal].self, from: data)
        else { return }
        scannedSignals = decoded
    }

    private func persistScannedSignals(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(scannedSignals) else { return }
        defaults.set(data, forKey: CacheKey.scannedSignals)
    }

    private func restoreHoldings(from defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: CacheKey.holdingsData),
            let decoded = try? JSONDecoder().decode([Holding].self, from: data)
        else { return }
        holdings = decoded
    }

    private func persistHoldings(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(holdings) else { return }
        defaults.set(data, forKey: CacheKey.holdingsData)
    }
}
