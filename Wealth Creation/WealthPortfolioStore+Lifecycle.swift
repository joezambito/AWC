import Foundation

extension WealthPortfolioStore {

    // MARK: - Post-startup Activity reconciliation

    /// Re-run the Activity admission pass after startup completes.
    ///
    /// Call this after both conditions are true:
    ///   1. `WealthEngineStartupController.isStartupComplete == true`
    ///   2. `WealthEngineStore.shared.tradingLifecycleArmed == true`
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
            detail: "rerunActivityAdmission: reconciliation triggered. AI Live cards: \(promotedCards.count).",
            category: "activity",
            tintName: promotedCards.isEmpty ? "orange" : "green",
            timestamp: .now
        )
    }
}
