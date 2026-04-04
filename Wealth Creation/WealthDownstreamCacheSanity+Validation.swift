import Foundation

// MARK: - WealthDownstreamCacheSanity+Validation
//
// Freshness checking, startup validation, and cache invalidation helpers
// for WealthDownstreamCacheSanity.
//
// See WealthDownstreamCacheSanity.swift for the class definition,
// file URLs, and persistence API.

extension WealthDownstreamCacheSanity {

    // MARK: - Freshness properties

    /// `true` when the AI Live results file exists and was written within
    /// `freshnessThreshold`.
    var isAILiveResultsFresh: Bool {
        isFileFresh(at: aiLiveResultsURL)
    }

    /// `true` when the Market snapshot file exists and was written within
    /// `freshnessThreshold`.
    var isMarketSnapshotFresh: Bool {
        isFileFresh(at: marketSnapshotURL)
    }

    /// `true` when the Activity state file exists and was written within
    /// `freshnessThreshold`.
    var isActivityStateFresh: Bool {
        isFileFresh(at: activityStateURL)
    }

    // MARK: - Startup validation

    /// Validate the freshness of all file-backed downstream caches.
    ///
    /// If any cache is stale or missing, hands off to
    /// `WealthStaleCacheDetector` so a downstream rebuild is triggered
    /// instead of silently reusing stale data.
    ///
    /// Called automatically from the `wealthEngineDidBecomeReady` observer
    /// registered in `init()`.  May also be called manually at any time.
    func validatePersistedDownstreamState() {
        let aiLiveFresh   = isAILiveResultsFresh
        let marketFresh   = isMarketSnapshotFresh
        let activityFresh = isActivityStateFresh

        let allFresh = aiLiveFresh && marketFresh && activityFresh

        var staleSummary: [String] = []
        if !aiLiveFresh   { staleSummary.append("AI Live") }
        if !marketFresh   { staleSummary.append("Market snapshot") }
        if !activityFresh { staleSummary.append("Activity state") }

        let detail: String
        if allFresh {
            detail = "All downstream caches are fresh – no rebuild needed."
        } else {
            detail = "Stale downstream caches detected: \(staleSummary.joined(separator: ", ")) – triggering rebuild."
        }

        WealthEventLogStore.shared.record(
            title: "Cache Sanity",
            detail: detail,
            category: "cache",
            tintName: allFresh ? "green" : "yellow",
            timestamp: .now
        )

        if !allFresh {
            WealthStaleCacheDetector.shared.checkAndRebuildIfNeeded()
        }
    }

    // MARK: - Cache invalidation

    /// Invalidate the AI Live results file cache.
    ///
    /// Called by `WealthStaleCacheDetector.checkAndRebuildIfNeeded()` before
    /// triggering a downstream rebuild so that the UI shows all Market cards
    /// without old AI Live exclusions while the fresh rebuild runs.
    func invalidateAILiveResults() {
        guard let url = aiLiveResultsURL else { return }
        try? FileManager.default.removeItem(at: url)
        WealthEventLogStore.shared.record(
            title: "Cache Sanity",
            detail: "Stale AI Live results invalidated before rebuild.",
            category: "cache",
            tintName: "orange",
            timestamp: .now
        )
    }

    /// Remove all file-backed downstream caches.
    /// Call on factory reset or sign-out to ensure stale data is not reused.
    func invalidateAllFileCaches() {
        let urls = [aiLiveResultsURL, marketSnapshotURL, activityStateURL]
            .compactMap { $0 }

        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }

        WealthEventLogStore.shared.record(
            title: "Cache Sanity",
            detail: "All file-backed downstream caches invalidated.",
            category: "cache",
            tintName: "orange",
            timestamp: .now
        )
    }

    // MARK: - Private freshness helper

    func isFileFresh(at url: URL?) -> Bool {
        guard let url else { return false }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date
        else { return false }
        return Date().timeIntervalSince(modified) <= freshnessThreshold
    }
}
