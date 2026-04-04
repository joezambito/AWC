import Foundation

// MARK: - WealthReadyStateGate
//
// Gates the engine's "fully ready" state so that it is declared only
// after the downstream rebuild pipeline has completed.
//
// Problem addressed:
//   The app previously declared itself ready immediately after the startup
//   sequence finished (or even after the cache was restored), before the
//   AI Live and Activity downstream passes had run.  This caused the UI to
//   show stale data as if it were live.
//
// Solution (new code only – no existing functions modified):
//   `isFullyReady` returns `true` only when BOTH conditions are met:
//     1. `WealthEngineStartupController.isStartupComplete` is `true`.
//     2. `WealthDownstreamRebuildOrchestrator` has called
//        `markDownstreamRebuildComplete()` at least once.
//
//   Subscribe to `Notification.Name.wealthEngineDidBecomeReady` to react
//   to the transition without polling.
//
// Fixes:
//   Error #6 – Ready-State Timing (app declares ready before rebuild is done)

@MainActor
final class WealthReadyStateGate {

    // MARK: Shared instance

    static let shared = WealthReadyStateGate()
    private init() {}

    // MARK: - State

    /// `true` once `WealthDownstreamRebuildOrchestrator` has completed at
    /// least one successful downstream rebuild.
    private(set) var isDownstreamRebuildComplete: Bool = false

    /// `true` when both the startup sequence and the downstream rebuild
    /// have completed.  This is the authoritative "engine fully ready" flag.
    ///
    /// Use this instead of `WealthEngineStartupController.isStartupComplete`
    /// whenever you need to know that live AI scores and Activity data are
    /// also available (not just the initial cache restore + scan sequence).
    var isFullyReady: Bool {
        WealthEngineStartupController.shared.isStartupComplete && isDownstreamRebuildComplete
    }

    // MARK: - Public API

    /// Called by `WealthDownstreamRebuildOrchestrator` when a rebuild
    /// finishes.  Posts `wealthEngineDidBecomeReady` the first time.
    func markDownstreamRebuildComplete() {
        let wasReady = isFullyReady
        isDownstreamRebuildComplete = true

        // Post the notification only on the first transition to fully-ready.
        if !wasReady && isFullyReady {
            NotificationCenter.default.post(
                name: .wealthEngineDidBecomeReady,
                object: nil
            )
        }
    }

    /// Reset the gate (e.g. after factory reset or sign-out).
    /// The gate must be re-armed by a subsequent downstream rebuild.
    func reset() {
        isDownstreamRebuildComplete = false
    }
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted on the main thread by `WealthReadyStateGate` the first time
    /// the engine transitions to `isFullyReady == true`.
    static let wealthEngineDidBecomeReady = Notification.Name("WealthEngineDidBecomeReady")
}
