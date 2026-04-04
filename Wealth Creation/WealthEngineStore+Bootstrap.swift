import Foundation

// MARK: - WealthEngineStore+Bootstrap
//
// Contains the startup entry-point called from ContentView / app lifecycle.
// Replaces the old "fire everything at once" pattern:
//
//  Old (broken):
//    bootstrap()
//      ├─ Universe scan  ← all fire simultaneously → UI freeze
//      ├─ AI scan
//      ├─ Market scan
//      └─ Research feeds
//
//  New (fixed):
//    bootstrap()
//      ├─ Restore cache immediately   ← UI visible with stale data
//      └─ WealthEngineStartupController.beginStartupSequence()
//           ├─ Universe scan (background)
//           ├─ wait 2 s
//           ├─ AI scan (background)
//           ├─ wait 1 s
//           ├─ Market ranking (background)
//           ├─ wait 1 s
//           └─ Research feeds (background)
//                └─ rescheduleTimers()

extension WealthEngineStore {

    // MARK: App bootstrap (called once on launch)

    /// Called from `ContentView.onAppear` / `WealthAppSessionController.prepareLaunch`.
    /// 1. Restores the most-recent persisted cache so the UI is immediately
    ///    populated with previously-seen data.
    /// 2. Hands off to `WealthEngineStartupController` which then runs each
    ///    scan phase in the background with deliberate staggering delays.
    func bootstrap() {
        // 1. Restore persisted state so the UI is not blank on launch.
        restoreCache()

        // 2. Kick off the staggered background startup.  The controller
        //    guards against duplicate invocations internally.
        WealthEngineStartupController.shared.beginStartupSequence()
    }
}
