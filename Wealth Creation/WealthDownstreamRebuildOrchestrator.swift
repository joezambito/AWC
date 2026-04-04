import Foundation

// MARK: - WealthDownstreamRebuildOrchestrator
//
// Sequences the Market → AI Live → Activity downstream pipeline and
// notifies the ready-state gate when the rebuild finishes.
//
// Problem addressed:
//   At startup and after unlock, the Market → AI Live → Activity pipeline
//   does not fire, leaving AI Live results missing/stale and Activity
//   unevaluated.
//
// Solution (new code only – no existing functions modified):
//   Calls the existing `runAIScan()` and `runMarketRanking()` entry-points
//   that are already defined in `WealthEngineStore+Refresh.swift`, then
//   signals `WealthReadyStateGate` on completion.  The existing functions
//   are unchanged; this class only orchestrates the order and timing.
//
//   Scan-progress gating (Issue 5): Before running the AI scan this
//   orchestrator checks `WealthScanProgressGate.canAILiveProceed`.  If
//   the universe scan has not yet reached the minimum threshold (e.g. the
//   orchestrator is triggered early during startup), it runs a universe
//   scan pass first so the AI scan operates on a sufficiently complete
//   asset universe.
//
// Fixes:
//   Error #3  – Forced Downstream Rebuild (pipeline doesn't fire at startup/unlock)
//   Error #4  – AI Live Regeneration (re-runs AI scan when scores are missing)
//   Error #5  – Activity Regeneration (re-runs Market ranking so Activity
//               consumers receive an updated ranked set after unlock)
//   Issue #5  – Scan Progress Gating (blocks AI Live on incomplete universe)

@MainActor
final class WealthDownstreamRebuildOrchestrator {

    // MARK: Shared instance

    static let shared = WealthDownstreamRebuildOrchestrator()
    private init() {}

    // MARK: Private state

    private var rebuildTask: Task<Void, Never>?

    // MARK: - Public API

    /// Trigger a downstream rebuild of the AI Live + Market + Activity
    /// pipeline.
    ///
    /// Safe to call from any context.  Re-entrant calls are no-ops while
    /// a rebuild is already in flight – the in-flight task will run to
    /// completion and notify the ready-state gate when done.
    ///
    /// - Parameter reason: A short human-readable label logged for diagnostics.
    func triggerRebuild(reason: String) {
        guard rebuildTask == nil else { return }

        WealthEventLogStore.shared.record(
            title: "Downstream Rebuild",
            detail: "Rebuild triggered: \(reason)",
            category: "orchestration",
            tintName: "blue",
            timestamp: .now
        )

        rebuildTask = Task { [weak self] in
            await self?.performDownstreamRebuild()
            self?.rebuildTask = nil
        }
    }

    /// Cancel any in-flight rebuild (e.g. during sign-out / factory reset).
    func cancelRebuild() {
        rebuildTask?.cancel()
        rebuildTask = nil
    }

    // MARK: - Private pipeline

    private func performDownstreamRebuild() async {
        let engine = WealthEngineStore.shared

        // Step 0: Scan-progress gate (Issue 5 fix).
        //
        // AI Live requires a sufficiently complete universe before it can
        // produce reliable promotion candidates.  If the scan-progress gate
        // is not yet open (e.g. this rebuild was triggered before the startup
        // controller's universe scan ran to completion), run a universe scan
        // pass first so the gate opens before the AI scan proceeds.
        if !WealthScanProgressGate.shared.canAILiveProceed {
            WealthEventLogStore.shared.record(
                title: "Downstream Rebuild",
                detail: "Scan progress below threshold – running universe scan before AI scan",
                category: "orchestration",
                tintName: "yellow",
                timestamp: .now
            )
            await engine.runUniverseScan()
            WealthScanProgressGate.shared.completeScan()
            guard !Task.isCancelled else { return }
        }

        // Step 1: Re-run the AI scan so every ranked card receives a fresh
        //         live score.  This is the AI Live pass in the pipeline.
        await engine.runAIScan()
        guard !Task.isCancelled else { return }

        // Step 2: Re-run Market ranking so the ranked set reflects the
        //         updated scores.  Activity consumers downstream will
        //         automatically receive the new ranked set.
        await engine.runMarketRanking()
        guard !Task.isCancelled else { return }

        // Step 3: Notify the ready-state gate that the downstream rebuild
        //         has completed.  The gate will declare the engine fully
        //         ready only after this point (Error #6 fix).
        WealthReadyStateGate.shared.markDownstreamRebuildComplete()
    }
}
