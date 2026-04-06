import Foundation

// MARK: - WealthEngineRuntimeCoordinator
//
// Receives lifecycle signals from `WealthAppSessionController` and
// orchestrates immediate stale-cache checks on active-session resumes.
//
// ── Problem it solves ────────────────────────────────────────────────────
//
//   Without this coordinator, when the app returned from background while
//   still unlocked (active session resume) the AI Live pipeline did not
//   re-evaluate.  The engine waited for the next heartbeat timer — up to
//   10 minutes — instead of triggering an immediate stale-cache check.
//
// ── Routing ──────────────────────────────────────────────────────────────
//
//   handleBecameActive()
//     │
//     ├─ [debounce < 2 s] → no-op (return)
//     │
//     ├─ [startup not complete] → no-op (startup sequence is running)
//     │
//     └─ [startup complete]
//          └─ WealthSessionUnlockController.shared.handleSessionResume()
//               └─ WealthStaleCacheDetector.shared.checkAndRebuildIfNeeded()
//                    └─ [if stale]
//                         └─ WealthDownstreamRebuildOrchestrator
//                              .shared.triggerRebuild(reason:)
//
// ── Debouncing ────────────────────────────────────────────────────────────
//
//   Rapid foreground/background transitions (e.g. biometric lock, control
//   centre swipe) can fire `applicationDidBecomeActive` multiple times in
//   quick succession.  The 2-second debounce window prevents a rebuild
//   storm in those cases.
//
// ── Startup guard ────────────────────────────────────────────────────────
//
//   If `WealthEngineStartupController.isStartupComplete` is `false`, the
//   startup sequence is already running the full pipeline — there is
//   nothing for the coordinator to do.  It returns immediately and logs
//   the skip so the event log is complete.
//
// ── Threading ─────────────────────────────────────────────────────────────
//
//   `@MainActor`.  `handleBecameActive()` is called on the main thread
//   from `WealthAppSessionController.applicationDidBecomeActive()`.
//   All downstream calls (`WealthSessionUnlockController`,
//   `WealthStaleCacheDetector`) are also `@MainActor`.

@MainActor
final class WealthEngineRuntimeCoordinator {

    // MARK: - Shared instance

    static let shared = WealthEngineRuntimeCoordinator()
    private init() {}

    // MARK: - Constants

    /// Minimum interval between consecutive active-resume checks.
    private let minimumResumeDebounceSecs: TimeInterval = 2

    // MARK: - Private state

    /// Timestamp of the most-recent `handleBecameActive` call.
    private var lastBecameActiveDate: Date?

    // MARK: - Public API

    /// Called by `WealthAppSessionController.applicationDidBecomeActive()`.
    ///
    /// Debounces rapid calls, guards against mid-startup invocations,
    /// then delegates to `WealthSessionUnlockController.handleSessionResume()`
    /// for an immediate stale-cache check.
    func handleBecameActive() {
        let now = Date()

        if let last = lastBecameActiveDate,
           now.timeIntervalSince(last) < minimumResumeDebounceSecs {
            return
        }
        lastBecameActiveDate = now

        WealthEventLogStore.shared.record(
            title: "Runtime Coordinator",
            detail: "handleBecameActive: evaluating recovery need.",
            category: "lifecycle",
            tintName: "blue",
            timestamp: now
        )

        guard WealthEngineStartupController.shared.isStartupComplete else {
            WealthEventLogStore.shared.record(
                title: "Runtime Coordinator",
                detail: "handleBecameActive: startup in progress — deferring to startup.",
                category: "lifecycle",
                tintName: "blue",
                timestamp: .now
            )
            return
        }

        WealthSessionUnlockController.shared.handleSessionResume()
    }
}
