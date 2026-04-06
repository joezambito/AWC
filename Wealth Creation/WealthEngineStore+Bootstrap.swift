import Foundation

// MARK: - WealthEngineStore+Bootstrap
//
// Contains the startup entry-points called from ContentView / app lifecycle.
//
// Entry-point routing (NEW unified path):
//
//   ContentView.onAppear
//     └─ WealthEngineStore.bootstrap()
//          └─ WealthAppSessionController.prepareLaunch()   ← single entry
//               ├─ WealthNewComponentsBootstrap.activate()
//               └─ restoreCacheInBackground { beginStartupSequence() }
//                    ├─ Universe scan (background, off main thread)
//                    ├─ wait 2 s
//                    ├─ AI scan (background)
//                    ├─ wait 1 s
//                    ├─ Market ranking (background)
//                    ├─ wait 1 s
//                    └─ Research feeds (background)
//                         └─ rescheduleTimers()
//
//   ContentView.onChange(scenePhase == .active)
//     └─ WealthEngineStore.handleForegroundActivation()
//          └─ WealthAppSessionController.applicationDidBecomeActive()
//               └─ WealthEngineRuntimeCoordinator.handleBecameActive()
//                    └─ stale-cache check (no full bootstrap re-run)
//
// Both ContentView entry-points are routed through WealthAppSessionController
// so that:
//   • The cache is ALWAYS restored off the main thread (no UI freeze).
//   • The full startup sequence runs AT MOST ONCE per app lifecycle.
//   • Foreground re-activations trigger only a stale-cache check, never
//     a redundant full bootstrap.

extension WealthEngineStore {

    // MARK: - App bootstrap (called once on launch from ContentView.onAppear)

    /// Route all startup work through `WealthAppSessionController.prepareLaunch()`.
    ///
    /// `prepareLaunch()` is guarded by a `hasLaunched` flag so it is
    /// idempotent – safe to call multiple times (e.g. scene reconnects).
    ///
    /// All cache I/O and scan phases run off the main thread so the UI
    /// never freezes on launch.
    func bootstrap() {
        WealthAppSessionController.shared.prepareLaunch()
    }

    // MARK: - Foreground activation (called from ContentView scenePhase observer)

    /// Route foreground re-activations through `WealthAppSessionController`
    /// rather than re-running the full bootstrap.
    ///
    /// On a warm open / unlock, this triggers a stale-cache check and
    /// downstream rebuild if needed.  On the very first launch (startup
    /// still in progress), this is a no-op so the startup sequence is
    /// not interrupted.
    func handleForegroundActivation() {
        WealthAppSessionController.shared.applicationDidBecomeActive()
    }
}
