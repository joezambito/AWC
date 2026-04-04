import Foundation

// MARK: - WealthEngineRuntimeCoordinator
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   When the app returns from background while still unlocked (active session
//   resume), the AI Live pipeline does not re-evaluate.  The engine waits for
//   the next heartbeat timer (up to 10 minutes) instead of triggering an
//   immediate stale-cache check and rebuild.
//
// Solution (new code only):
//   `WealthEngineRuntimeCoordinator` receives lifecycle signals from
//   `WealthAppSessionController` and immediately checks whether a downstream
//   rebuild is needed rather than waiting for the next timer tick.
//
//   On `handleBecameActive()`:
//     a. If startup is not yet complete → no-op (startup sequence already running).
//     b. If startup is complete but app was backgrounded → call
//        `WealthSessionUnlockController.handleSessionResume()` which then
//        calls `WealthStaleCacheDetector.checkAndRebuildIfNeeded()`.
//     c. If a rebuild is already in flight → no-op (deduplicated internally
//        by `WealthDownstreamRebuildOrchestrator`).
//
// Fixes:
//   Blocker #2 – Active-session resumes not forcing recovery
//   Problem #9 – Make resume recovery immediate

@MainActor
final class WealthEngineRuntimeCoordinator {

    // MARK: Shared instance

    static let shared = WealthEngineRuntimeCoordinator()
    private init() {}

    // MARK: - Private state

    /// Timestamp of the most-recent `applicationDidBecomeActive` event.
    /// Used to debounce rapid foreground/background transitions.
    private var lastBecameActiveDate: Date?

    /// Minimum interval between consecutive active-resume checks.
    /// Prevents a rapid background → foreground cycle from spamming rebuilds.
    private let minimumResumeDebounceSecs: TimeInterval = 2

    // MARK: - Public API

    /// Called by `WealthAppSessionController.applicationDidBecomeActive()`.
    ///
    /// Triggers an immediate stale-cache check and rebuild if warranted,
    /// rather than waiting for the next scheduled heartbeat timer.
    func handleBecameActive() {
        let now = Date()

        // Debounce: ignore calls within the minimum interval.
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

        // If startup has not yet completed, the startup sequence is
        // running the full pipeline.  No additional action is needed.
        guard WealthEngineStartupController.shared.isStartupComplete else {
            WealthEventLogStore.shared.record(
                title: "Runtime Coordinator",
                detail: "handleBecameActive: startup in progress – deferring to startup.",
                category: "lifecycle",
                tintName: "blue",
                timestamp: .now
            )
            return
        }

        // Startup is complete.  The session is live (still unlocked) or
        // has just been unlocked/resumed.  Trigger an immediate session
        // resume check which will detect stale state and rebuild if needed.
        WealthSessionUnlockController.shared.handleSessionResume()
    }
}
