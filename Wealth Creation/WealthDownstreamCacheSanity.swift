import Foundation

// MARK: - WealthDownstreamCacheSanity
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   1. `WealthEngineStore+Cache.swift` stores all data (including 128 k
//      ranked assets) in UserDefaults.  UserDefaults is unreliable for large
//      payloads and offers no modification-time metadata for freshness checks.
//   2. AI Live results and Activity state have no persistent backing at all –
//      they vanish on every app restart, causing the 0-card state after reopen.
//   3. On startup, the engine reuses any persisted state without validating
//      whether it is still fresh, causing stale data to be treated as live.
//
// Solution (new code only):
//   • `WealthDownstreamCacheSanity` writes AI Live results and the Market
//     snapshot to the app's Caches directory as JSON files.  Files are
//     atomic-write so they are never partially written.
//   • `validateOnStartup()` reads file-modification timestamps and compares
//     them against a freshness threshold.  If stale or missing, it calls
//     `WealthStaleCacheDetector.shared.checkAndRebuildIfNeeded()` to trigger
//     a downstream rebuild instead of silently reusing stale data.
//   • A NotificationCenter observer auto-triggers validation after the ready
//     notification fires so the sanity check runs on every launch without
//     requiring changes to existing bootstrap code.
//
// Fixes:
//   Error #11 – Cache Persistence Sanity

@MainActor
final class WealthDownstreamCacheSanity {

    // MARK: Shared instance

    static let shared = WealthDownstreamCacheSanity()

    // MARK: Init – register lifecycle observer

    private init() {
        // Auto-trigger sanity validation after the engine becomes ready.
        // This runs without requiring any modification to existing bootstrap
        // or startup-controller code.
        NotificationCenter.default.addObserver(
            forName: .wealthEngineDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.validatePersistedDownstreamState()
            }
        }
    }

    // MARK: - Freshness threshold

    /// Downstream state older than this interval is treated as stale.
    /// Matches the deep-refresh timer (30 min) used elsewhere in the engine.
    private let freshnessThreshold: TimeInterval = 30 * 60

    // MARK: - File URLs

    /// Root directory for all file-backed downstream caches.
    private var cacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    /// File-backed storage for AI Live results (array of scored Opportunity).
    private var aiLiveResultsURL: URL? {
        cacheDirectory?.appendingPathComponent("awc_ai_live_results.json")
    }

    /// File-backed storage for the Market snapshot (top-N ranked cards).
    private var marketSnapshotURL: URL? {
        cacheDirectory?.appendingPathComponent("awc_market_snapshot.json")
    }

    /// File-backed storage for Activity admission state (admitted card symbols).
    private var activityStateURL: URL? {
        cacheDirectory?.appendingPathComponent("awc_activity_state.json")
    }

    // MARK: - Public persistence API

    // ── AI Live results ──────────────────────────────────────────────────

    /// Persist AI Live results to a file (NOT UserDefaults).
    /// Call after the AI scan updates aiScore values on ranked cards.
    func saveAILiveResults(_ results: [Opportunity]) {
        persistToFile(results, url: aiLiveResultsURL, label: "AI Live results")
    }

    /// Restore AI Live results from file.
    /// Returns an empty array when the file is absent or unreadable.
    func loadAILiveResults() -> [Opportunity] {
        loadFromFile([Opportunity].self, url: aiLiveResultsURL, label: "AI Live results") ?? []
    }

    // ── Market snapshot ──────────────────────────────────────────────────

    /// Persist the current Market ranking snapshot to file.
    /// Call after `materializeMarketCandidates()` completes.
    func saveMarketSnapshot(_ cards: [Opportunity]) {
        persistToFile(cards, url: marketSnapshotURL, label: "Market snapshot")
    }

    /// Restore the most recently persisted Market snapshot from file.
    func loadMarketSnapshot() -> [Opportunity] {
        loadFromFile([Opportunity].self, url: marketSnapshotURL, label: "Market snapshot") ?? []
    }

    // ── Activity state ───────────────────────────────────────────────────

    /// Persist the admitted Activity card symbols to file.
    func saveActivityState(_ symbols: [String]) {
        persistToFile(symbols, url: activityStateURL, label: "Activity state")
    }

    /// Restore admitted Activity card symbols from file.
    func loadActivityState() -> [String] {
        loadFromFile([String].self, url: activityStateURL, label: "Activity state") ?? []
    }

    // MARK: - Freshness validation

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
        let aiLiveFresh    = isAILiveResultsFresh
        let marketFresh    = isMarketSnapshotFresh
        let activityFresh  = isActivityStateFresh

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

    // MARK: - Private helpers

    private func isFileFresh(at url: URL?) -> Bool {
        guard let url else { return false }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date
        else { return false }
        return Date().timeIntervalSince(modified) <= freshnessThreshold
    }

    private func persistToFile<T: Encodable>(_ value: T, url: URL?, label: String) {
        guard let url else { return }
        guard let data = try? JSONEncoder().encode(value) else { return }
        do {
            try data.write(to: url, options: [.atomic])
            WealthEventLogStore.shared.record(
                title: "Cache Sanity",
                detail: "\(label) persisted to file (\(data.count / 1024) KB).",
                category: "cache",
                tintName: "blue",
                timestamp: .now
            )
        } catch {
            WealthEventLogStore.shared.record(
                title: "Cache Sanity",
                detail: "Failed to persist \(label): \(error.localizedDescription)",
                category: "cache",
                tintName: "red",
                timestamp: .now
            )
        }
    }

    private func loadFromFile<T: Decodable>(_ type: T.Type, url: URL?, label: String) -> T? {
        guard let url,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(type, from: data)
        else { return nil }
        return decoded
    }
}
