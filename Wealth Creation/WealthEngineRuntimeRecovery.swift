import Foundation

@MainActor
final class WealthEngineRuntimeRecovery {

    static let shared = WealthEngineRuntimeRecovery()
    private init() {}

    // MARK: - Startup integrity check

    func runStartupIntegrityCheck() {
        let engine = WealthEngineStore.shared
        var repairs: [String] = []

        if engine.isDashboardRefreshInFlight {
            engine.isDashboardRefreshInFlight = false
            repairs.append("dashboard-refresh-flag")
        }

        if engine.isMarketMaterializationInFlight {
            engine.isMarketMaterializationInFlight = false
            repairs.append("materialization-flag")
        }

        if engine.activationTask != nil {
            engine.activationTask = nil
            repairs.append("activation-task")
        }
        if engine.pendingRefreshPayload != nil {
            engine.pendingRefreshPayload = nil
            repairs.append("pending-payload")
        }
        if engine.pendingPublishTask != nil {
            engine.pendingPublishTask = nil
            repairs.append("pending-publish-task")
        }

        WealthReadyStateGate.shared.reset()
        WealthDownstreamRebuildOrchestrator.shared.cancelRebuild()
        WealthEngineScanScheduler.shared.reset()

        if repairs.isEmpty {
            WealthEventLogStore.shared.record(
                title: "Runtime Recovery",
                detail: "Startup integrity check passed – no stuck state found.",
                category: "recovery",
                tintName: "green",
                timestamp: .now
            )
        } else {
            WealthEventLogStore.shared.record(
                title: "Runtime Recovery",
                detail: "Startup integrity check repaired: \(repairs.joined(separator: ", "))",
                category: "recovery",
                tintName: "orange",
                timestamp: .now
            )
        }
    }

    // MARK: - Full recovery

    func performFullRecovery(reason: String) {
        WealthEventLogStore.shared.record(
            title: "Runtime Recovery",
            detail: "Full recovery triggered: \(reason)",
            category: "recovery",
            tintName: "red",
            timestamp: .now
        )

        WealthDownstreamRebuildOrchestrator.shared.cancelRebuild()
        WealthSessionUnlockController.shared.cancelSessionResume()
        WealthReadyStateGate.shared.reset()
        WealthEngineStore.shared.recoverFromFailedRefresh(reason: reason)
    }
}
