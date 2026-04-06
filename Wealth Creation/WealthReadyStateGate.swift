import Foundation

// MARK: - WealthReadyStateGate
//
// Gates the engine's "fully ready" state so that it is declared only
// after the downstream rebuild pipeline has completed.
//
// ── Problem it solves ────────────────────────────────────────────────────
//
//   Without this gate, the app declared itself "ready" immediately after
//   `WealthEngineStartupController.isStartupComplete` became `true` — which
//   happens after the research feeds phase, before the downstream AI Live
//   and Activity passes have run.  Views subscribed to readiness would show
//   stale data as if it were live.
//
// ── Two-condition readiness ───────────────────────────────────────────────
//
//   `isFullyReady` returns `true` only when BOTH of the following hold:
//
//   1. `WealthEngineStartupController.shared.isStartupComplete == true`
//      — the universe scan, AI scan, market ranking, and research feeds
//        have all completed.
//
//   2. `markDownstreamRebuildComplete()` has been called at least once
//      — `WealthDownstreamRebuildOrchestrator` has finished its AI + Market
//        rebuild after the startup sequence, confirming that live AI scores
//        and Activity state are available.
//
// ── Notification ─────────────────────────────────────────────────────────
//
//   When `isFullyReady` transitions from `false` to `true`,
//   `Notification.Name.wealthEngineDidBecomeReady` is posted on the main
//   thread.  Observers include:
//
//   • `WealthPortfolioLifecycleHelper` — triggers Activity reconciliation
//   • `WealthBackgroundRefreshCoordinator` — schedules the first background
//     refresh
//   • `WealthNewComponentsBootstrap` — runs the post-ready pipeline
//     (market audit, AI Live evaluation, order-restriction audit)
//
//   The notification is posted exactly once per gate reset cycle.
//   Subsequent calls to `markDownstreamRebuildComplete()` are no-ops
//   if `isFullyReady` is already `true`.
//
// ── Reset ─────────────────────────────────────────────────────────────────
//
//   `reset()` is called by `WealthEngineRuntimeRecovery.runStartupIntegrityCheck()`
//   at the beginning of each startup integrity check.  After a reset the gate
//   must be re-armed by a subsequent `markDownstreamRebuildComplete()` call.
//
// ── Threading ─────────────────────────────────────────────────────────────
//
//   `@MainActor` — all state mutations and notification posts happen on the
//   main thread.  No external synchronisation is needed.

@MainActor
final class WealthReadyStateGate {

    // MARK: - Shared instance

    static let shared = WealthReadyStateGate()
    private init() {}

    // MARK: - State

    /// `true` once `markDownstreamRebuildComplete()` has been called at least once
    /// since the last `reset()`.
    private(set) var isDownstreamRebuildComplete: Bool = false

    /// The authoritative "engine fully ready" flag.
    ///
    /// `true` when both the startup sequence and the first downstream
    /// rebuild have completed.
    ///
    /// Use this — not `WealthEngineStartupController.isStartupComplete` — when
    /// you need to confirm that live AI scores and Activity data are available.
    var isFullyReady: Bool {
        WealthEngineStartupController.shared.isStartupComplete && isDownstreamRebuildComplete
    }

    // MARK: - Public API

    /// Mark the downstream rebuild as complete.
    ///
    /// Called by `WealthDownstreamRebuildOrchestrator` after each successful
    /// rebuild.  Posts `.wealthEngineDidBecomeReady` the first time
    /// `isFullyReady` transitions to `true`.
    func markDownstreamRebuildComplete() {
        let wasReady = isFullyReady
        isDownstreamRebuildComplete = true

        if !wasReady && isFullyReady {
            NotificationCenter.default.post(
                name: .wealthEngineDidBecomeReady,
                object: nil
            )
        }
    }

    /// Reset the gate (e.g. after factory reset or sign-out).
    ///
    /// The gate must be re-armed by a subsequent `markDownstreamRebuildComplete()`
    /// call before `isFullyReady` can return `true` again.
    func reset() {
        isDownstreamRebuildComplete = false
    }
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted on the main thread by `WealthReadyStateGate` the first time
    /// the engine transitions to `isFullyReady == true`.
    ///
    /// `userInfo` is `nil`.  Observers that need data should read from the
    /// engine stores directly in response to this notification.
    static let wealthEngineDidBecomeReady = Notification.Name("WealthEngineDidBecomeReady")
}
