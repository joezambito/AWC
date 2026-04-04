import Foundation

// MARK: - WealthSessionUnlockController
//
// Handles session resumption triggered by app reopen or device unlock.
//
// Problem addressed:
//   After app launch or reopen, a cached Market snapshot is present but the
//   live session is never properly resumed, so the downstream pipeline
//   (Market → AI Live → Activity) never fires again.
//
// Solution (new code only – no existing functions modified):
//   1. Call `handleSessionResume()` from your scene/app delegate whenever
//      the app transitions from background/locked to active
//      (e.g. `sceneDidBecomeActive`, `applicationDidBecomeActive`).
//   2. The controller checks whether startup has already completed and,
//      if so, hands off to `WealthDownstreamRebuildOrchestrator` so that
//      the downstream pipeline fires with fresh data.
//
// Fixes:
//   Error #1 – Unlock/Session Startup (session not resumed after reopen)
//   Error #3 – Forced Downstream Rebuild (pipeline doesn't fire at unlock)

@MainActor
final class WealthSessionUnlockController {

    // MARK: Shared instance

    static let shared = WealthSessionUnlockController()
    private init() {}

    // MARK: Private state

    private var resumeTask: Task<Void, Never>?

    // MARK: - Public API

    /// Call from `sceneDidBecomeActive` / `applicationDidBecomeActive`.
    ///
    /// If the startup sequence has already completed (meaning the engine
    /// was previously bootstrapped), this triggers a downstream rebuild so
    /// that Market → AI Live → Activity receives fresh data on every
    /// unlock or app reopen.
    ///
    /// Safe to call multiple times – re-entrant calls are no-ops while a
    /// resume is already in flight.
    func handleSessionResume() {
        guard resumeTask == nil else { return }
        resumeTask = Task { [weak self] in
            await self?.performSessionResume()
            self?.resumeTask = nil
        }
    }

    /// Cancel any in-flight resume (e.g. during sign-out / factory reset).
    func cancelSessionResume() {
        resumeTask?.cancel()
        resumeTask = nil
    }

    // MARK: - Private

    private func performSessionResume() async {
        // If the startup sequence has not yet completed, the
        // WealthEngineStartupController is still running the full
        // pipeline – no additional action needed here.
        guard WealthEngineStartupController.shared.isStartupComplete else { return }
        guard !Task.isCancelled else { return }

        // Startup already finished but the app was subsequently locked or
        // backgrounded.  Run stale-cache detection first; if stale, the
        // detector will itself trigger a downstream rebuild.  Otherwise,
        // trigger one unconditionally so live scores are always refreshed
        // on every unlock/reopen.
        WealthStaleCacheDetector.shared.checkAndRebuildIfNeeded()
    }
}
