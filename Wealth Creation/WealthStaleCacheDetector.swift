import Foundation

// MARK: - WealthStaleCacheDetector
//
// Detects mismatches between cached Market data and downstream state so
// that a rebuild can be triggered before the UI presents stale results.
//
// Problem addressed:
//   The engine may restore a Market cache (`rankedAssets` is non-empty)
//   while AI Live scores are absent or all-zero, meaning the downstream
//   state is inconsistent.  No detection of this mismatch previously
//   existed.
//
// Solution (new code only – no existing functions modified):
//   • `isCachedMarketWithoutLiveScores()` – detects the Market-exists /
//     AI-scores-absent mismatch.
//   • `isCacheStale(threshold:)` – detects data older than a threshold.
//   • `isAILiveResultsStale()` – detects stale AI Live file cache.
//   • `checkAndRebuildIfNeeded()` – combines all checks and delegates to
//     `WealthDownstreamRebuildOrchestrator` when any condition is true.
//     Uses the 5-minute post-unlock threshold per the problem statement.
//
// Fixes:
//   Error #2 – Stale-Cache Detection
//   Error #4 – AI Live Regeneration (detects missing AI scores and
//              signals the orchestrator to re-run the AI + Market pipeline)

@MainActor
final class WealthStaleCacheDetector {

    // MARK: Shared instance

    static let shared = WealthStaleCacheDetector()
    private init() {}

    // MARK: Stale-data thresholds

    /// Post-unlock stale threshold: if last refresh is older than this,
    /// force a downstream rebuild so live AI scores are always refreshed
    /// on every unlock or app reopen.  5 minutes matches the problem
    /// statement requirement ("stale lastRefresh > 5 min").
    let postUnlockStaleThreshold: TimeInterval = 5 * 60

    /// Background freshness threshold: matches the deep-refresh timer (30 min)
    /// used for background validation by `WealthDownstreamCacheSanity`.
    let backgroundFreshnessThreshold: TimeInterval = 30 * 60

    // MARK: - Public API

    /// Returns `true` when `rankedAssets` is non-empty (Market cache
    /// restored) but every ranked asset has an AI score of zero, meaning
    /// the AI Live pass has never run or its results were lost.
    func isCachedMarketWithoutLiveScores() -> Bool {
        let engine = WealthEngineStore.shared
        guard !engine.rankedAssets.isEmpty else { return false }
        return !engine.rankedAssets.contains { $0.aiScore > 0 }
    }

    /// Returns `true` when the engine's last-refresh timestamp is older
    /// than `threshold`, or when no timestamp exists (fresh install / reset).
    func isCacheStale(threshold: TimeInterval) -> Bool {
        guard let lastRefresh = WealthEngineStore.shared.lastRefresh else {
            return true
        }
        return Date().timeIntervalSince(lastRefresh) > threshold
    }

    /// Convenience overload using the post-unlock stale threshold (5 min).
    func isCacheStale() -> Bool {
        isCacheStale(threshold: postUnlockStaleThreshold)
    }

    /// Returns `true` when the AI Live results file is missing or was
    /// written more than `postUnlockStaleThreshold` ago.
    func isAILiveResultsStale() -> Bool {
        !WealthDownstreamCacheSanity.shared.isAILiveResultsFresh
    }

    /// Returns `true` when the Activity state file is missing or stale.
    func isActivityStateStale() -> Bool {
        !WealthDownstreamCacheSanity.shared.isActivityStateFresh
    }

    /// Run all stale-cache checks and trigger a downstream rebuild when
    /// any condition is detected.
    ///
    /// Checks (any one triggers rebuild):
    ///   1. Cached Market cards but AI Live scores all-zero
    ///   2. Last refresh older than 5 minutes (post-unlock threshold)
    ///   3. AI Live results file is missing or stale
    ///   4. Activity state file is missing or stale
    ///
    /// When stale AI Live results are detected, they are invalidated before
    /// the rebuild so the UI shows all Market cards without old exclusions
    /// while the fresh AI Live pass runs.
    ///
    /// This is the primary call-site used by `WealthSessionUnlockController`
    /// on every unlock / app reopen.
    func checkAndRebuildIfNeeded() {
        let missingLiveScores  = isCachedMarketWithoutLiveScores()
        let cacheIsStale       = isCacheStale()
        let aiLiveStale        = isAILiveResultsStale()
        let activityStale      = isActivityStateStale()

        var reasons: [String] = []
        if missingLiveScores  { reasons.append("missing-ai-live-scores") }
        if cacheIsStale       { reasons.append("stale-cache->5min") }
        if aiLiveStale        { reasons.append("stale-ai-live-file") }
        if activityStale      { reasons.append("stale-activity-file") }

        let needsRebuild = !reasons.isEmpty

        if needsRebuild {
            // Invalidate stale AI Live results so the UI shows Market cards
            // without old exclusions while the fresh rebuild runs.
            if missingLiveScores || aiLiveStale {
                WealthDownstreamCacheSanity.shared.invalidateAILiveResults()
            }
            let reason = reasons.joined(separator: ", ")
            WealthDownstreamRebuildOrchestrator.shared.triggerRebuild(reason: reason)
        } else {
            // Cache is fresh; trigger a lightweight rebuild anyway so
            // Activity always re-evaluates after unlock.
            WealthDownstreamRebuildOrchestrator.shared.triggerRebuild(reason: "session-resume")
        }
    }
}
