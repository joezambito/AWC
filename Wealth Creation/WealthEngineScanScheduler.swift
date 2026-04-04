import Foundation

// MARK: - WealthEngineScanScheduler
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   The AI Live pass can attempt to promote Market cards before the universe
//   scan has reached a minimum completion threshold.  This causes AI Live
//   results to be built from a partial universe, leading to stale rankings
//   and empty Activity queues.
//
// Solution (new code only):
//   `WealthEngineScanScheduler` tracks an observable scan-progress value
//   (0.0 – 1.0) that is updated as each phase of the startup sequence
//   completes.  Downstream consumers (notably `WealthAILiveCoordinator`)
//   read `currentProgress` before evaluating candidates and gate promotion
//   behind `minimumProgressForAILive`.
//
// Fixes:
//   Blocker #5 – Scan progress gate missing from AI Live visibility
//   Problem #7 – AI Live starvation: scan progress not at minimum gate

@MainActor
final class WealthEngineScanScheduler {

    // MARK: Shared instance

    static let shared = WealthEngineScanScheduler()
    private init() {}

    // MARK: - Scan phases

    /// Ordered list of scan phases.  Progress is computed as completed /
    /// total phases so the value is uniformly distributed across the pipeline.
    enum ScanPhase: Int, CaseIterable {
        case cacheRestore  = 0
        case universeScan  = 1
        case aiScan        = 2
        case marketRanking = 3
        case researchFeeds = 4
    }

    // MARK: - Progress state

    /// Current overall scan progress (0.0 = no phases complete, 1.0 = all done).
    private(set) var currentProgress: Double = 0

    /// The minimum scan progress required before AI Live is allowed to
    /// promote Market candidates.  Requires at least universe scan + AI scan
    /// complete (phases 1 and 2 of 4 data phases → 0.5).
    let minimumProgressForAILive: Double = 0.5

    /// `true` when the scan has reached the AI Live promotion gate.
    var hasReachedAILiveGate: Bool {
        currentProgress >= minimumProgressForAILive
    }

    // MARK: - Phase tracking

    private var completedPhases: Set<ScanPhase> = []

    // MARK: - Public API

    /// Mark a scan phase as complete and update `currentProgress`.
    ///
    /// Safe to call multiple times for the same phase – duplicate calls
    /// are no-ops.
    func markPhaseComplete(_ phase: ScanPhase) {
        guard !completedPhases.contains(phase) else { return }
        completedPhases.insert(phase)

        let totalPhases = Double(ScanPhase.allCases.count)
        currentProgress = Double(completedPhases.count) / totalPhases

        WealthEventLogStore.shared.record(
            title: "Scan Scheduler",
            detail: "Phase complete: \(phase) | progress=\(String(format: "%.0f%%", currentProgress * 100))",
            category: "orchestration",
            tintName: currentProgress >= minimumProgressForAILive ? "green" : "blue",
            timestamp: .now
        )

        // Post a notification so any observer (e.g. AI Live coordinator)
        // can react to progress changes without polling.
        NotificationCenter.default.post(
            name: .wealthScanProgressDidUpdate,
            object: nil,
            userInfo: ["progress": currentProgress]
        )
    }

    /// Reset the scheduler (e.g. after factory reset or for a new scan cycle).
    func reset() {
        completedPhases.removeAll()
        currentProgress = 0
    }
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted on the main thread whenever `WealthEngineScanScheduler`
    /// updates scan progress.  `userInfo["progress"]` contains the new
    /// `Double` value (0.0 – 1.0).
    static let wealthScanProgressDidUpdate = Notification.Name("WealthScanProgressDidUpdate")
}
