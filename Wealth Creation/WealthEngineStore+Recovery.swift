import Foundation

// MARK: - WealthEngineStore+Recovery
//
// Downstream recovery helpers.  When a scan phase fails or produces
// results that are inconsistent with the current state, these methods
// restore the engine to a safe baseline so subsequent timers can
// attempt a fresh run.

extension WealthEngineStore {

    // MARK: - Public API

    /// Attempt to recover from a failed or interrupted refresh cycle.
    ///
    /// - Clears any in-flight task handles that may have been left dangling.
    /// - Resets loading flags so the UI does not spin indefinitely.
    /// - Falls back to the last-known-good persisted snapshot so the UI
    ///   remains populated.
    /// - Logs the recovery event for diagnostics.
    func recoverFromFailedRefresh(reason: String) {
        // Clear in-flight flags
        isDashboardRefreshInFlight = false
        isMarketMaterializationInFlight = false

        // Release dangling task handles
        activationTask = nil
        pendingRefreshPayload = nil
        pendingPublishTask = nil

        // Restore last persisted state so the UI is not blank
        restoreCache()

        WealthEventLogStore.shared.record(
            title: "Recovery",
            detail: "Engine recovered from failed refresh: \(reason)",
            category: "recovery",
            tintName: "orange",
            timestamp: .now
        )
    }

    /// Full engine reset back to factory defaults.
    /// Clears all cached state and cancels the startup sequence so the
    /// next `bootstrap()` call starts completely fresh.
    ///
    /// NOTE: This method extends (replaces) the stub `resetToFactoryDefaults()`
    /// in `WealthCore.swift`.  Once the core file is refactored, remove the
    /// original stub and keep only this implementation.
    func resetToFactoryDefaults() {
        WealthEngineStartupController.shared.cancelStartupSequence()
        invalidateTimers()

        isDashboardRefreshInFlight = false
        isMarketMaterializationInFlight = false
        activationTask = nil
        pendingRefreshPayload = nil
        pendingPublishTask = nil

        rankedAssets = []
        scannedSignals = []
        holdings = []
        lastRefresh = nil
        lastHeavyRefresh = nil

        clearPersistedCache()
    }

    // MARK: - Private helpers

    private func clearPersistedCache() {
        // Remove lightweight UserDefaults timestamps
        let defaultsKeys = [
            "awc_engine_last_refresh",
            "awc_engine_last_heavy_refresh"
        ]
        let defaults = UserDefaults.standard
        defaultsKeys.forEach { defaults.removeObject(forKey: $0) }

        // Remove file-backed large-array caches
        let fm       = FileManager.default
        let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
        let fileNames = [
            "awc_engine_ranked_assets.json",
            "awc_engine_scanned_signals.json",
            "awc_engine_holdings.json"
        ]
        for name in fileNames {
            if let url = cacheDir?.appendingPathComponent(name) {
                try? fm.removeItem(at: url)
            }
        }

        // Remove downstream file-backed caches
        WealthDownstreamCacheSanity.shared.invalidateAllFileCaches()
    }
}
