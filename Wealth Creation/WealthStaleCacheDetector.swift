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
//   • `checkAndRebuildIfNeeded()` – combines both checks and delegates to
//     `WealthDownstreamRebuildOrchestrator` when either condition is true.
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

    // MARK: Stale-data threshold

    /// Cache is considered stale when the last refresh is older than this
    /// interval (default: 30 minutes, matching the deep-refresh timer).
    private let defaultThreshold: TimeInterval = 30 * 60

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

    /// Run both stale-cache checks and trigger a downstream rebuild when
    /// either condition is detected.
    ///
    /// This is the primary call-site used by `WealthSessionUnlockController`
    /// on every unlock / app reopen.
    func checkAndRebuildIfNeeded() {
        let missingLiveScores = isCachedMarketWithoutLiveScores()
        let cacheIsStale      = isCacheStale()

        if missingLiveScores || cacheIsStale {
            let reason = missingLiveScores ? "missing-ai-live-scores" : "stale-cache"
            WealthDownstreamRebuildOrchestrator.shared.triggerRebuild(reason: reason)
        } else {
            // Cache is fresh and live scores are present; trigger a lightweight
            // rebuild anyway so Activity always re-evaluates after unlock.
            WealthDownstreamRebuildOrchestrator.shared.triggerRebuild(reason: "session-resume")
        }
    }
}
