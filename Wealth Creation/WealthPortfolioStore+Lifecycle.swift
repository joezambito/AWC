import Foundation

// MARK: - WealthPortfolioStore+Lifecycle
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   Activity admission (the final stage of the pipeline) depends on
//   `tradingLifecycleArmed` being `true`.  During startup, this flag is
//   `false`, so Activity reconciliation is skipped.  After startup finishes
//   and the flag becomes `true`, reconciliation is never re-run, leaving
//   Activity permanently empty until the next heartbeat timer fires.
//
// Solution (new code only):
//   `rerunActivityAdmissionAfterStartup()` is called by
//   `WealthPortfolioLifecycleHelper` once it detects the
//   `wealthEngineDidBecomeReady` notification AND `tradingLifecycleArmed`
//   is `true`.  This ensures the admission logic runs at least once on
//   every startup, even when the timer has not yet fired.
//
// Fixes:
//   Blocker #6 – Activity reconciliation not rerun after startup completion

extension WealthPortfolioStore {

    // MARK: - Post-startup Activity reconciliation

    /// Re-run the Activity admission pass after startup completes.
    ///
    /// Call this after both conditions are true:
    ///   1. `WealthEngineStartupController.isStartupComplete == true`
    ///   2. `tradingLifecycleArmed == true`
    ///
    /// This method is a gate wrapper: it confirms the armed state, runs the
    /// admission audit for diagnostics, and then triggers the admission pass.
    /// It does NOT change the admission logic itself.
    func rerunActivityAdmissionAfterStartup() {
        guard tradingLifecycleArmed else {
            WealthEventLogStore.shared.record(
                title: "Portfolio Lifecycle",
                detail: "rerunActivityAdmission: trading lifecycle not armed – skipping.",
                category: "activity",
                tintName: "orange",
                timestamp: .now
            )
            return
        }

        // Run the admission audit so the diagnostic counters are up-to-date.
        let promotedCards = WealthAILiveCoordinator.shared.promotedCards
        WealthActivityAdmissionAudit.shared.runAudit(on: promotedCards)

        // Trigger the Activity admission pass.
        reconcileActivityAdmissions()

        WealthEventLogStore.shared.record(
            title: "Portfolio Lifecycle",
            detail: "rerunActivityAdmission: reconciliation triggered. AI Live cards: \(promotedCards.count).",
            category: "activity",
            tintName: promotedCards.isEmpty ? "orange" : "green",
            timestamp: .now
        )
    }
}
