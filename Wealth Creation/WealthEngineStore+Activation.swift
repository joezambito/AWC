import Foundation

// MARK: - WealthEngineStore+Activation
//
// Bridges the original `runActivationSequence()` call site in WealthCore.swift
// to the new LAYERED startup controller (`WealthEngineStartupController`).
//
// Timer audit (properties that existed in the original WealthCore.swift):
//
//   REMOVED (legacy – no longer used):
//     • preScanBurstTimer      – fired a rapid pre-scan burst; superseded by
//                                the staggered startup sequence in the controller.
//     • scheduledCheckpointTimer – checkpoint counter logic; superseded by the
//                                  9 m / 19 m / 29 m IBKR timers + 10 m / 20 m
//                                  soft timers + 30 m deep timer.
//
//   KEPT (active, managed by WealthEngineStore+Timers.swift):
//     • softTimer   – holds the 10-minute soft-refresh timer reference.
//     • heavyTimer  – holds the 30-minute deep-refresh timer reference.
//     • timerHolder.ibkrTimers       – IBKR price-only timers (9 m, 19 m, 29 m).
//     • timerHolder.extraSoftTimers  – second soft-refresh timer (20 m).
//
// Startup sequence (LAYERED – one phase at a time, never parallel):
//
//   1. bootstrap() → WealthAppSessionController.prepareLaunch()
//        ├─ WealthNewComponentsBootstrap.activate()   (pipeline singletons)
//        └─ restoreCacheInBackground { beginStartupSequence() }
//              ↓
//   2. Universe scan  (runUniverseScanWithProgress)
//              ↓  2 s gap
//   3. AI scan        (runAIScanWithProgress)
//              ↓  1 s gap
//   4. Market ranking (runMarketRankingWithProgress)
//              ↓  1 s gap
//   5. Research feeds (runResearchFeedsWithProgress)
//              ↓
//   6. Timers start   (rescheduleTimers)
//              ↓
//   7. Recurring checkpoints fire (9 m IBKR → 10 m soft → … → 30 m deep)

extension WealthEngineStore {

    // MARK: - Activation sequence

    /// Bridge the legacy `runActivationSequence()` call site to the new
    /// layered `WealthEngineStartupController`.
    ///
    /// All existing timer properties are torn down via `invalidateTimers()`
    /// before handing off, so no residual timers can fire during the
    /// startup phases.  The startup controller's guard prevents a second
    /// run if a sequence is already in progress.
    func runActivationSequence() {
        // Tear down ALL current timers (softTimer, heavyTimer, IBKR timers,
        // extra soft timers) so none can fire during the startup sequence.
        invalidateTimers()

        // Hand off to the single, authoritative layered startup path.
        // WealthEngineStartupController.beginStartupSequence() is idempotent:
        // a second call while a startup is already running is a no-op.
        WealthEngineStartupController.shared.beginStartupSequence()
    }
}
