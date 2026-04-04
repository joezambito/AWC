import Foundation

// MARK: - WealthEngineRuntimeRecovery
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   When a scan phase fails or the app is abruptly interrupted (crash,
//   force-quit, out-of-memory termination), the engine can be left in a
//   half-built state on the next launch:
//     • In-flight flags stuck at `true` (UI spins indefinitely)
//     • Task handles referencing cancelled tasks
//     • Persisted cache from a partial run
//     • Ready-state gate never re-armed
//
// Solution (new code only):
//   `WealthEngineRuntimeRecovery.runStartupIntegrityCheck()` is called by
//   `WealthEngineStartupController` after cache restore and before beginning
//   the startup sequence.  It checks for each of the known stuck-state
//   patterns and resets only the affected flags without wiping good data.
//
//   A full factory-reset path (`performFullRecovery()`) is available for
//   cases where integrity cannot be restored incrementally.
//
// Fixes:
//   Problem #9  – Make resume recovery immediate
//   Problem #10 – Relock behavior: recovery is immediate + complete

@MainActor
final class WealthEngineRuntimeRecovery {

    // MARK: Shared instance

    static let shared = WealthEngineRuntimeRecovery()
    private init() {}

    // MARK: - Startup integrity check

    /// Pre-flight check run at the START of each startup sequence (before
    /// `beginStartupSequence()` executes its first scan phase).
    ///
    /// Detects and resets any stuck in-flight state left by a previous
    /// interrupted session so the new startup begins from a clean baseline.
    ///
    /// Safe to call multiple times – each call is idempotent.
    func runStartupIntegrityCheck() {
        let engine = WealthEngineStore.shared

        var repairs: [String] = []

        // Reset stuck dashboard-refresh flag
        if engine.isDashboardRefreshInFlight {
            engine.isDashboardRefreshInFlight = false
            repairs.append("dashboard-refresh-flag")
        }

        // Reset stuck materialization flag
        if engine.isMarketMaterializationInFlight {
            engine.isMarketMaterializationInFlight = false
            repairs.append("materialization-flag")
        }

        // Clear dangling task handles
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

        // Reset the ready-state gate so the next rebuild arms it fresh.
        WealthReadyStateGate.shared.reset()
        WealthDownstreamRebuildOrchestrator.shared.cancelRebuild()

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

    /// Perform a full recovery when incremental repair is insufficient.
    ///
    /// Resets all engine state, clears persisted caches, cancels the startup
    /// sequence, and re-arms the startup sequence from a clean baseline.
    ///
    /// Use when: persistent decode failures, irrecoverable corruption, or
    /// after a programmatic sign-out / factory reset.
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
