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
//   Additionally, AI Live uses a strict 5-minute freshness window on its
//   intake gate.  If Market cards were loaded from cache with a refresh
//   timestamp older than 5 minutes, AI Live rejects ALL candidates even
//   though healthy cards are present — causing 0 AI Live results while the
//   UI shows a non-empty Market.
//
// Solution (new code only – no existing functions modified):
//   • `isCachedMarketWithoutLiveScores()` – detects the Market-exists /
//     AI-scores-absent mismatch.
//   • `isCacheStale(threshold:)` – detects data older than a threshold.
//   • `isAILiveFreshnessWindowExpired()` – detects when Market cards exist
//     but their refresh is older than the AI Live 5-minute window (Issue 3).
//   • `checkAndRebuildIfNeeded()` – combines all checks and delegates to
//     `WealthDownstreamRebuildOrchestrator` when any condition is true.
//
// Fixes:
//   Error #2  – Stale-Cache Detection
//   Error #4  – AI Live Regeneration (detects missing AI scores and
//               signals the orchestrator to re-run the AI + Market pipeline)
//   Issue #3  – AI Live Candidate Starvation (5-minute freshness window)

@MainActor
final class WealthStaleCacheDetector {

    // MARK: Shared instance

    static let shared = WealthStaleCacheDetector()
    private init() {}

    // MARK: Stale-data thresholds

    /// Cache is considered stale when the last refresh is older than this
    /// interval (default: 30 minutes, matching the deep-refresh timer).
    private let defaultThreshold: TimeInterval = 30 * 60

    /// AI Live uses a strict 5-minute freshness window on its intake gate.
    /// Market cards older than this interval are rejected by AI Live even
    /// when healthy cards are present, causing candidate starvation.
    private let aiLiveFreshnessWindow: TimeInterval = 5 * 60

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

    /// Convenience overload using `defaultThreshold`.
    func isCacheStale() -> Bool {
        isCacheStale(threshold: defaultThreshold)
    }

    /// Returns `true` when ranked Market cards exist but their last-refresh
    /// timestamp is older than the AI Live freshness window (5 minutes).
    ///
    /// AI Live's intake gate rejects all candidates whose refresh exceeds
    /// this window, so stale cached Market data silently produces 0 AI Live
    /// results even when healthy cards are present.  Detecting this
    /// condition here allows `checkAndRebuildIfNeeded()` to force a fresh
    /// rebuild before the UI session is treated as live (Issue 3 fix).
    func isAILiveFreshnessWindowExpired() -> Bool {
        guard !WealthEngineStore.shared.rankedAssets.isEmpty else { return false }
        return isCacheStale(threshold: aiLiveFreshnessWindow)
    }

    /// Run all stale-cache checks and trigger a downstream rebuild when
    /// any condition is detected.
    ///
    /// This is the primary call-site used by `WealthSessionUnlockController`
    /// on every unlock / app reopen.
    func checkAndRebuildIfNeeded() {
        let missingLiveScores        = isCachedMarketWithoutLiveScores()
        let cacheIsStale             = isCacheStale()
        let aiLiveFreshnessExpired   = isAILiveFreshnessWindowExpired()

        if missingLiveScores || cacheIsStale || aiLiveFreshnessExpired {
            let reason: String
            if missingLiveScores {
                reason = "missing-ai-live-scores"
            } else if aiLiveFreshnessExpired {
                // Market cards exist but are too old for AI Live intake (Issue 3)
                reason = "ai-live-freshness-expired"
            } else {
                reason = "stale-cache"
            }
            WealthDownstreamRebuildOrchestrator.shared.triggerRebuild(reason: reason)
        } else {
            // Cache is fresh and live scores are present; trigger a lightweight
            // rebuild anyway so Activity always re-evaluates after unlock.
            WealthDownstreamRebuildOrchestrator.shared.triggerRebuild(reason: "session-resume")
        }
    }
}
