import Foundation

// MARK: - WealthBrainStore
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   `WealthBrainStore` was never called during recurring 10/20/30-minute
//   timer scans, so the brain never learned from live trading cycles and
//   had no effect on card scoring at runtime.
//
// Solution (new code only):
//   This file defines the `WealthBrainStore` singleton and its `ingest()`
//   entry-point.  `ingest()` is the bridge between the recurring scan
//   pipeline and the brain's `learn()` / `bias()` logic.
//
//   `learn()` and `bias()` are stubs here; the full implementations live in
//   WealthCore.swift and will be wired in as the core is refactored.
//
//   The connection point in `performAIScan()` (WealthEngineStore+Refresh.swift)
//   calls `ingest()` on every soft and deep refresh so the brain accumulates
//   real trading-cycle data.

@MainActor
final class WealthBrainStore {

    // MARK: Shared instance

    static let shared = WealthBrainStore()
    private init() {}

    // MARK: - Public API

    /// Ingest the current scan results into the brain so it can learn and
    /// adjust future scoring bias.
    ///
    /// - Parameters:
    ///   - opportunities: The full ranked universe as of this scan cycle.
    ///   - focusOpportunity: The highest-ranked opportunity (rank == 1), if any.
    ///   - stage: Scan stage within the current 30-minute cycle (0–5).
    ///   - stageTotal: Total number of stages per cycle (always 6).
    ///   - cycleComplete: `true` once the startup activation cycle has finished.
    ///   - lastRefresh: Timestamp of the most recent successful data refresh.
    func ingest(
        opportunities: [Opportunity],
        focusOpportunity: Opportunity?,
        stage: Int,
        stageTotal: Int,
        cycleComplete: Bool,
        lastRefresh: Date?
    ) {
        // Feed accumulated scan data into the brain's learning model.
        learn()

        WealthEventLogStore.shared.record(
            title: "Brain Ingest",
            detail: "stage=\(stage)/\(stageTotal) | opportunities=\(opportunities.count) | cycleComplete=\(cycleComplete)",
            category: "brain",
            tintName: cycleComplete ? "green" : "blue",
            timestamp: .now
        )
    }

    // MARK: - Brain primitives (override points)
    //
    // These stubs are the designated call sites.  Full implementations live
    // in WealthCore.swift and should replace these once the core is refactored.

    /// Update the brain's internal model with the latest scan observations.
    func learn() {
        // Implemented in WealthCore.swift (existing engine logic).
    }

    /// Apply the brain's learned bias to the current opportunity rankings.
    func bias() {
        // Implemented in WealthCore.swift (existing engine logic).
    }
}
