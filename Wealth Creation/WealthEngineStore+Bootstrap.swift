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
//      └─ First launch:
//           WealthEngineStartupController.beginStartupSequence()
//             ├─ Universe scan (background)
//             ├─ wait 2 s
//             ├─ AI scan (background)
//             ├─ wait 1 s
//             ├─ Market ranking (background)
//             ├─ wait 1 s
//             ├─ Research feeds (background)
//             └─ Downstream rebuild: AI Live → Activity
//                  └─ rescheduleTimers()
//
//         Unlock/reopen (startup already done, Market cached but AI Live stale):
//           WealthEngineStartupController.resumeSession()
//             └─ Downstream rebuild: Market (cached) → AI Live → Activity
//                  └─ rescheduleTimers()

extension WealthEngineStore {

    // MARK: App bootstrap (called once on launch AND on foreground/unlock)

    /// Called from `ContentView.onAppear` / `WealthAppSessionController.prepareLaunch`.
    ///
    /// Handles two scenarios:
    ///
    /// 1. **First launch** – restores cache for immediate UI, then kicks off the
    ///    full staggered startup sequence via `WealthEngineStartupController`.
    ///
    /// 2. **Unlock / reopen** (startup already completed) – restores cache, then
    ///    checks whether the downstream AI Live pipeline is stale.  If so, a
    ///    targeted downstream rebuild is triggered immediately so the UI never
    ///    shows empty AI Live / Activity data.
    func bootstrap() {
        // 1. Restore persisted state so the UI is not blank on launch.
        restoreCache()

        let controller = WealthEngineStartupController.shared

        // 2. Unlock / reopen: startup already ran but downstream may be stale.
        if controller.isStartupComplete {
            if isCachedMarketWithStaleAILive {
                // Fix 2 (stale-cache detection) + Fix 3 (forced downstream rebuild):
                // Market is cached but AI Live has not been rebuilt this session.
                // Run the downstream pipeline before declaring the session ready.
                controller.resumeSession()
            }
            return
        }

        // 3. First launch: kick off the staggered background startup.
        //    The controller guards against duplicate invocations internally.
        controller.beginStartupSequence()
    }

    // MARK: - Stale-cache detection (Fix 2)

    /// `true` when the engine has cached Market cards but the AI Live
    /// downstream pipeline has not completed in the current session.
    ///
    /// This is the key stale-cache rule: cached Market alone is NOT
    /// sufficient to treat startup as ready — the downstream rebuild must
    /// also have completed.
    var isCachedMarketWithStaleAILive: Bool {
        !rankedAssets.isEmpty &&
        !WealthEngineStartupController.shared.isDownstreamRebuildComplete
    }
}
