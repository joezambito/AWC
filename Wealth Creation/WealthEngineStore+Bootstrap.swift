import Foundation

// MARK: - WealthEngineStore+Bootstrap
//
// ── Startup entry-points (called from ContentView / app lifecycle) ────────
//
// PREFERRED path (use this):
//
//   ContentView.onAppear
//     └─ WealthEngineStore.bootstrap()
//          └─ WealthAppSessionController.prepareLaunch()
//               ├─ WealthNewComponentsBootstrap.activate()    ← register observers
//               └─ restoreCacheInBackground { beginStartupSequence() }
//                    ├─ WealthEngineRuntimeRecovery.runStartupIntegrityCheck()
//                    ├─ Universe scan (background, off main thread)
//                    ├─ wait 2 s
//                    ├─ AI scan (background)
//                    ├─ wait 1 s
//                    ├─ Market ranking (background)
//                    ├─ wait 1 s
//                    └─ Research feeds (background)
//                         └─ rescheduleTimers()  (6 timers: 9/10/19/20/29/30 min)
//
// LEGACY path (WealthCore.swift only – do not add new callers):
//
//   WealthCore.swift
//     └─ WealthEngineStore.runActivationSequence()  (WealthEngineStore+Activation.swift)
//
// ── Foreground re-activation ──────────────────────────────────────────────
//
//   ContentView.onChange(scenePhase == .active)
//     └─ WealthEngineStore.handleForegroundActivation()
//          └─ WealthAppSessionController.applicationDidBecomeActive()
//               └─ WealthEngineRuntimeCoordinator.handleBecameActive()
//                    └─ WealthSessionUnlockController.handleSessionResume()
//                         └─ WealthStaleCacheDetector.checkAndRebuildIfNeeded()
//
// ── Guarantees ────────────────────────────────────────────────────────────
//
//   • cache restore is ALWAYS off the main thread (no UI freeze on launch)
//   • full startup sequence runs AT MOST ONCE (WealthAppSessionController.hasLaunched)
//   • foreground re-activations trigger only a stale-cache check, NOT a full restart
//   • timer scheduling happens AFTER the startup sequence completes

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
