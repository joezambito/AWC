import Foundation

// MARK: - WealthEngineRefresh+LifecyclePublishing
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   Downstream consumers (AI Live coordinator, Activity admission) have no
//   way to know when a refresh cycle has started or finished, or which phase
//   is currently running.  Without this information, they either evaluate
//   stale data too early or wait indefinitely for a signal that never arrives.
//
// Solution (new code only):
//   Adds lifecycle-publishing wrappers around the existing scan entry-points
//   in `WealthEngineStore+Refresh.swift`.  Each wrapper:
//     1. Posts a `willBeginPhase` notification before the scan.
//     2. Marks the phase complete in `WealthEngineScanScheduler`.
//     3. Posts a `didCompletePhase` notification after the scan.
//   All notifications are posted on the main thread.
//
// Fixes:
//   Blocker #5 – Scan progress gate missing from AI Live visibility
//   Problem #3  – Stale-cache handling: downstream knows when to re-evaluate

extension WealthEngineStore {

    // MARK: - Lifecycle-publishing scan wrappers

    /// Universe scan with scan-scheduler progress tracking.
    ///
    /// Replaces direct calls to `runUniverseScan()` in the startup sequence
    /// so progress is always recorded.  The original `runUniverseScan()` is
    /// unchanged and still available for callers that do not need tracking.
    func runUniverseScanWithProgress() async {
        postRefreshPhaseWillBegin(.universeScan)
        await runUniverseScan()
        WealthEngineScanScheduler.shared.markPhaseComplete(.universeScan)
        postRefreshPhaseDidComplete(.universeScan)
    }

    /// AI scan with scan-scheduler progress tracking.
    func runAIScanWithProgress() async {
        postRefreshPhaseWillBegin(.aiScan)
        await runAIScan()
        WealthEngineScanScheduler.shared.markPhaseComplete(.aiScan)
        postRefreshPhaseDidComplete(.aiScan)
    }

    /// Market ranking with scan-scheduler progress tracking.
    func runMarketRankingWithProgress() async {
        postRefreshPhaseWillBegin(.marketRanking)
        await runMarketRanking()
        WealthEngineScanScheduler.shared.markPhaseComplete(.marketRanking)
        postRefreshPhaseDidComplete(.marketRanking)
    }

    /// Research feeds with scan-scheduler progress tracking.
    func runResearchFeedsWithProgress() async {
        postRefreshPhaseWillBegin(.researchFeeds)
        await runResearchFeeds()
        WealthEngineScanScheduler.shared.markPhaseComplete(.researchFeeds)
        postRefreshPhaseDidComplete(.researchFeeds)
    }

    // MARK: - Private notification helpers

    private func postRefreshPhaseWillBegin(_ phase: WealthEngineScanScheduler.ScanPhase) {
        NotificationCenter.default.post(
            name: .wealthRefreshPhaseWillBegin,
            object: nil,
            userInfo: ["phase": phase.rawValue]
        )
    }

    private func postRefreshPhaseDidComplete(_ phase: WealthEngineScanScheduler.ScanPhase) {
        NotificationCenter.default.post(
            name: .wealthRefreshPhaseDidComplete,
            object: nil,
            userInfo: ["phase": phase.rawValue]
        )
    }
}

// MARK: - Notification names

extension Notification.Name {
    /// Posted on the main thread just before a scan phase begins.
    /// `userInfo["phase"]` contains the raw `Int` value of
    /// `WealthEngineScanScheduler.ScanPhase`.
    static let wealthRefreshPhaseWillBegin    = Notification.Name("WealthRefreshPhaseWillBegin")

    /// Posted on the main thread immediately after a scan phase finishes.
    /// `userInfo["phase"]` contains the raw `Int` value of
    /// `WealthEngineScanScheduler.ScanPhase`.
    static let wealthRefreshPhaseDidComplete  = Notification.Name("WealthRefreshPhaseDidComplete")
}
