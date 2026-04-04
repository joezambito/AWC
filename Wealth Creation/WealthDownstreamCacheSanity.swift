import Foundation

// MARK: - WealthDownstreamCacheSanity
//
// Writes AI Live results, the Market snapshot, and Activity state to file-
// backed JSON caches in the app's Caches directory.  Atomic writes ensure
// files are never partially written.
//
// See WealthDownstreamCacheSanity+Validation.swift for freshness checking,
// startup validation, and cache-invalidation helpers.
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
    let freshnessThreshold: TimeInterval = 30 * 60

    // MARK: - File URLs

    /// Root directory for all file-backed downstream caches.
    private var cacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    /// File-backed storage for AI Live results (array of scored Opportunity).
    var aiLiveResultsURL: URL? {
        cacheDirectory?.appendingPathComponent("awc_ai_live_results.json")
    }

    /// File-backed storage for the Market snapshot (top-N ranked cards).
    var marketSnapshotURL: URL? {
        cacheDirectory?.appendingPathComponent("awc_market_snapshot.json")
    }

    /// File-backed storage for Activity admission state (admitted card symbols).
    var activityStateURL: URL? {
        cacheDirectory?.appendingPathComponent("awc_activity_state.json")
    }

    // MARK: - Public persistence API

    // ── AI Live results ──────────────────────────────────────────────────

    /// Persist AI Live results to a file (NOT UserDefaults).
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

    // MARK: - Internal file I/O helpers

    func persistToFile<T: Encodable>(_ value: T, url: URL?, label: String) {
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

    func loadFromFile<T: Decodable>(_ type: T.Type, url: URL?, label: String) -> T? {
        guard let url,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(type, from: data)
        else { return nil }
        return decoded
    }
}
