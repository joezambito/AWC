import Foundation

// MARK: - WealthEngineStore+Bootstrap
//
// All startup and foreground-activation entry-points for ContentView and
// the app-delegate lifecycle.
//
// ── Launch flow ──────────────────────────────────────────────────────────
//
//   ContentView.onAppear
//     └─ WealthEngineStore.bootstrap()
//          └─ WealthAppSessionController.prepareLaunch()   ← single entry
//               ├─ guard !hasLaunched (idempotent)
//               ├─ WealthNewComponentsBootstrap.activate()
//               └─ restoreCacheInBackground {
//                       WealthEngineStartupController
//                         .shared.beginStartupSequence()
//                  }
//                    ├─ Universe scan  (background)   +2 s delay
//                    ├─ AI scan        (background)   +1 s delay
//                    ├─ Market ranking (background)   +1 s delay
//                    └─ Research feeds (background)
//                         └─ rescheduleTimers()
//                              └─ markDownstreamRebuildComplete()
//                                   └─ post wealthEngineDidBecomeReady
//
//   ContentView.onChange(scenePhase == .active)
//     └─ WealthEngineStore.handleForegroundActivation()
//          └─ WealthAppSessionController.applicationDidBecomeActive()
//               └─ WealthEngineRuntimeCoordinator.handleBecameActive()
//                    └─ WealthSessionUnlockController.handleSessionResume()
//                         └─ WealthStaleCacheDetector.checkAndRebuildIfNeeded()
//
//   ContentView.onChange(scenePhase == .background)
//     └─ WealthEngineStore.handleBackgroundTransition()
//          └─ WealthAppSessionController.applicationDidEnterBackground()
//               └─ WealthEngineStore.saveInBackground()
//
// ── Idempotency ───────────────────────────────────────────────────────────
//
//   `bootstrap()` and `runActivationSequence()` both call `prepareLaunch()`.
//   `prepareLaunch()` is guarded by `hasLaunched` so the full startup
//   sequence runs at most once per process lifetime.
//
//   `WealthEngineStartupController.beginStartupSequence()` adds a second
//   guard: it checks `startupTask == nil && !isStartupComplete` before
//   spawning a new detached Task.
//
// ── Threading ────────────────────────────────────────────────────────────
//
//   `bootstrap()` and `handleForegroundActivation()` are called on
//   @MainActor.  All blocking work (cache I/O, CSV loading, network scans)
//   is immediately dispatched to a background Task.detached so the UI
//   thread is never blocked during launch or reopen.
//
// ── Foreground re-activations ────────────────────────────────────────────
//
//   On a warm reopen (app was backgrounded while unlocked),
//   `handleForegroundActivation()` does NOT re-run bootstrap.  Instead it
//   routes through WealthEngineRuntimeCoordinator which checks whether the
//   stale-cache detector needs to run.  This prevents a double scan while
//   the scheduled timers handle routine refreshes at their configured
//   intervals (soft: 9/19/29 min, heavy: 10/20/30 min).
//
// ── Background saves ─────────────────────────────────────────────────────
//
//   `handleBackgroundTransition()` and `handleTermination()` both call
//   `saveInBackground()` which encodes the ranked-asset and holdings state
//   to the persistent bundle off the main thread.  This ensures that on the
//   next cold launch `restoreCacheInBackground()` can immediately populate
//   the UI without waiting for a full network scan.

extension WealthEngineStore {

    // MARK: - Launch bootstrap

    /// Primary launch entry-point — call once from `ContentView.onAppear`.
    ///
    /// Idempotent: safe to call multiple times (scene reconnects, previews).
    /// All heavy work runs off the main thread.
    func bootstrap() {
        WealthAppSessionController.shared.prepareLaunch()
    }

    // MARK: - Foreground activation

    /// Call from the `ContentView` `scenePhase == .active` observer.
    ///
    /// Triggers a stale-cache check on warm reopen without re-running the
    /// full bootstrap.  No-op while the initial startup sequence is still
    /// in progress.
    func handleForegroundActivation() {
        WealthAppSessionController.shared.applicationDidBecomeActive()
    }

    // MARK: - Background transition

    /// Call from the `ContentView` `scenePhase == .background` observer.
    ///
    /// Cancels any pending session-resume and initiates a background save
    /// so that ranked-asset and holdings state survives a process kill.
    func handleBackgroundTransition() {
        WealthAppSessionController.shared.applicationDidEnterBackground()
    }

    // MARK: - Termination

    /// Call from `applicationWillTerminate`.
    ///
    /// Initiates a final background save.  Performed asynchronously so the
    /// main thread is never blocked by the OS watchdog during termination.
    func handleTermination() {
        WealthAppSessionController.shared.applicationWillTerminate()
    }

    // MARK: - Pipeline bootstrap convenience

    /// Same as `bootstrap()` with an explicit pipeline-activation step.
    ///
    /// `bootstrap()` already calls `WealthNewComponentsBootstrap.activate()`
    /// internally via `prepareLaunch()`.  The explicit call below is a
    /// no-op on normal paths but guards against callers that bypass
    /// `prepareLaunch()` in WealthCore.swift.
    func bootstrapWithPipeline() {
        bootstrap()
        WealthNewComponentsBootstrap.activate()
    }
}
