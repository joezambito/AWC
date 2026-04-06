import Foundation

// MARK: - WealthEngineStore+Activation
//
// Thin delegation shim — single entry-point for WealthCore.swift.
//
// ── Why this file exists ──────────────────────────────────────────────────
//
//   `WealthCore.swift` (real source, not in git) calls
//   `runActivationSequence()` on `WealthEngineStore`.  That call-site is
//   not directly editable here.  This extension redirects it to the
//   canonical startup path: `WealthAppSessionController.prepareLaunch()`.
//
// ── Startup path ─────────────────────────────────────────────────────────
//
//   runActivationSequence()
//     └─ WealthAppSessionController.shared.prepareLaunch()
//          ├─ guard !hasLaunched  (idempotent — runs at most once)
//          ├─ WealthNewComponentsBootstrap.activate()
//          └─ WealthEngineStore.restoreCacheInBackground {
//                  WealthEngineStartupController.shared.beginStartupSequence()
//             }
//
//   The same path is used by `WealthEngineStore.bootstrap()` (called from
//   ContentView).  Both converge on `prepareLaunch()` so the full startup
//   sequence can never be triggered twice.
//
// ── Guard: isStartupComplete ─────────────────────────────────────────────
//
//   `WealthEngineStartupController.beginStartupSequence()` checks:
//     • `startupTask == nil`       — no task is already in flight
//     • `!isStartupComplete`       — startup has not already succeeded
//
//   `runActivationSequence()` additionally checks:
//     • `!WealthEngineStartupController.shared.isStartupComplete`
//
//   Together these guards ensure the startup pipeline fires exactly once
//   regardless of how many times ContentView or WealthCore calls the
//   entry-points.
//
// ── Thread safety ─────────────────────────────────────────────────────────
//
//   `runActivationSequence()` is called on @MainActor (the WealthEngineStore
//   actor context).  `prepareLaunch()` immediately dispatches all blocking
//   work (cache I/O, CSV loading, network scans) to background Tasks via
//   `Task.detached(priority: .userInitiated)` so the main thread is never
//   blocked.
//
// ── Relationship to bootstrap() ───────────────────────────────────────────
//
//   ContentView calls `bootstrap()` on `WealthEngineStore`
//   (see WealthEngineStore+Bootstrap.swift).  WealthCore.swift calls
//   `runActivationSequence()`.  Both methods call `prepareLaunch()`.
//   The `hasLaunched` flag on WealthAppSessionController ensures that
//   whichever fires first wins and subsequent calls are silently ignored.
//
// ── tradingLifecycleArmed ─────────────────────────────────────────────────
//
//   After the full startup sequence completes, `WealthEngineStartupController`
//   sets `WealthEngineStore.shared.tradingLifecycleArmed = true` and calls
//   `rescheduleTimers()`.  This property gates the Activity admission audit
//   and is checked by `WealthPortfolioStore+Lifecycle` before reconciling
//   Activity admissions.

extension WealthEngineStore {

    // MARK: - Legacy activation entry-point

    /// Called by `WealthCore.swift` at app startup.
    ///
    /// Delegates to `WealthAppSessionController.shared.prepareLaunch()`
    /// which is idempotent — the full startup sequence runs at most once
    /// per process lifetime regardless of how many times this method is
    /// called.
    func runActivationSequence() {
        guard !WealthEngineStartupController.shared.isStartupComplete else { return }
        WealthAppSessionController.shared.prepareLaunch()
    }
}
