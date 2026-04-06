import Foundation

// MARK: - WealthPortfolioStore+Lifecycle
//
// Post-startup Activity reconciliation for WealthPortfolioStore.
//
// ── Purpose ───────────────────────────────────────────────────────────────
//
//   After the startup sequence completes and `tradingLifecycleArmed` is set
//   to `true` on `WealthEngineStore`, the Activity admission pass must be
//   re-run so that cards promoted by AI Live are visible in the Activity
//   queue immediately — rather than waiting for the next scheduled timer.
//
//   This extension provides `rerunActivityAdmissionAfterStartup()` which is
//   called by `WealthPortfolioLifecycleHelper` once `tradingLifecycleArmed`
//   becomes `true`.
//
// ── Guard: tradingLifecycleArmed ─────────────────────────────────────────
//
//   The guard ensures the Activity reconciliation only fires after the full
//   startup pipeline has completed.  Calling before that point would mean
//   reconciling against a stale or partial AI Live promoted set, which could
//   result in wrong Activity state persisting until the next timer cycle.
//
//   `tradingLifecycleArmed` is set to `true` by:
//     • WealthEngineStartupController at the end of `runStartupSequence()`
//     • WealthEngineStore+Activation if the startup completes via the
//       legacy `runActivationSequence()` path
//
// ── Promoted cards source ─────────────────────────────────────────────────
//
//   `promotedCards` comes from `WealthAILiveCoordinator.shared.promotedCards`.
//   These are the cards that passed the 75% risk re-validation pass in
//   `evaluateCandidates()` and are eligible for Activity admission.
//
//   If `promotedCards` is empty it means either:
//     a) The AI Live evaluation pass has not yet run.
//     b) No market cards passed the risk re-validation threshold.
//   In both cases the event log receives an orange-tinted entry so the
//   condition is visible for diagnostics.
//
// ── reconcileActivityAdmissions() ────────────────────────────────────────
//
//   `reconcileActivityAdmissions()` is defined in WealthCore.swift (not in
//   git).  It walks the promoted-card set, runs each card through the
//   Activity admission audit, and updates the Activity queue accordingly.
//   It does NOT re-trigger a full AI Live evaluation — it uses the already-
//   computed `promotedCards` as its input.
//
// ── Threading ─────────────────────────────────────────────────────────────
//
//   Called on @MainActor.  `reconcileActivityAdmissions()` accesses
//   `WealthEngineStore.shared` and `WealthAILiveCoordinator.shared` which
//   are both @MainActor-confined, so no additional dispatching is needed.

extension WealthPortfolioStore {

    // MARK: - Post-startup reconciliation

    /// Re-run the Activity admission pass after startup completes.
    ///
    /// Guarded by `WealthEngineStore.shared.tradingLifecycleArmed`.
    /// Call this from `WealthPortfolioLifecycleHelper` once that flag
    /// becomes `true`.
    func rerunActivityAdmissionAfterStartup() {
        guard WealthEngineStore.shared.tradingLifecycleArmed else {
            WealthEventLogStore.shared.record(
                title: "Portfolio Lifecycle",
                detail: "rerunActivityAdmission: trading lifecycle not armed – skipping.",
                category: "activity",
                tintName: "orange",
                timestamp: .now
            )
            return
        }

        let promotedCards = WealthAILiveCoordinator.shared.promotedCards
        WealthActivityAdmissionAudit.shared.runAudit(on: promotedCards)

        reconcileActivityAdmissions()

        WealthEventLogStore.shared.record(
            title: "Portfolio Lifecycle",
            detail: "rerunActivityAdmission: reconciliation complete. AI Live cards: \(promotedCards.count).",
            category: "activity",
            tintName: promotedCards.isEmpty ? "orange" : "green",
            timestamp: .now
        )
    }
}
