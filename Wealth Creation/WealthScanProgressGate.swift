import Foundation

// MARK: - WealthScanProgressGate
//
// Tracks universe-scan progress and gates the AI Live pipeline until a
// minimum scan-completion threshold is reached.
//
// Problem addressed (Issue 5 – Scan Progress Gating):
//   AI Live visibility/exclusion had no scan-progress gate — the AI Live
//   pass was being evaluated against an incomplete universe, causing
//   candidate starvation even when healthy cards existed but had not yet
//   been scored.
//
// Solution (new code only – no existing functions modified):
//   `WealthScanProgressGate` receives progress updates from the universe
//   scan and exposes `canAILiveProceed` which returns `true` only when at
//   least `minimumCompletionPercent` of the universe has been processed.
//   `WealthDownstreamRebuildOrchestrator` queries the gate before
//   advancing to the AI scan step; if the gate is closed it first runs a
//   universe-scan pass to populate the asset universe.
//
// Fixes:
//   Issue 5 – Scan Progress Gating (blocks AI Live on incomplete universe)

@MainActor
final class WealthScanProgressGate {

    // MARK: Shared instance

    static let shared = WealthScanProgressGate()
    private init() {}

    // MARK: - Configuration

    /// Minimum scan completion percentage (0–100) required before AI Live
    /// is allowed to proceed.  Cards scored below this threshold represent
    /// an incomplete universe that would starve the AI Live intake filter.
    var minimumCompletionPercent: Int = 60

    // MARK: - State

    /// Current scan completion percentage (0–100).
    /// Updated by the universe-scan pass via `recordProgress(_:)`.
    private(set) var currentProgressPercent: Int = 0

    /// Total number of assets the scanner expects to process this cycle.
    /// Set at the start of each scan via `beginScan(totalAssets:)`.
    private(set) var totalAssets: Int = 0

    /// Number of assets processed so far this cycle.
    private(set) var processedAssets: Int = 0

    // MARK: - Public API

    /// Signal the start of a new scan cycle.
    ///
    /// Resets progress counters so stale progress from a previous cycle
    /// does not prevent AI Live from proceeding on the new cycle.
    func beginScan(totalAssets: Int) {
        self.totalAssets = max(totalAssets, 1)   // avoid division by zero
        processedAssets = 0
        currentProgressPercent = 0

        WealthEventLogStore.shared.record(
            title: "Scan Progress",
            detail: "Scan started – \(self.totalAssets) assets expected",
            category: "orchestration",
            tintName: "blue",
            timestamp: .now
        )
    }

    /// Record that `count` additional assets have been processed.
    ///
    /// Recomputes `currentProgressPercent` and posts
    /// `wealthScanProgressDidReachMinimum` the first time the gate
    /// threshold is crossed.
    func recordProgress(_ count: Int) {
        processedAssets = min(processedAssets + count, totalAssets)
        let previous = currentProgressPercent
        currentProgressPercent = totalAssets > 0
            ? Int((Double(processedAssets) / Double(totalAssets)) * 100)
            : 100

        // Log at every 10 % milestone to reduce log noise
        if currentProgressPercent / 10 > previous / 10 {
            WealthEventLogStore.shared.record(
                title: "Scan Progress",
                detail: "\(currentProgressPercent)% complete (\(processedAssets)/\(totalAssets))",
                category: "orchestration",
                tintName: currentProgressPercent >= minimumCompletionPercent ? "green" : "yellow",
                timestamp: .now
            )
        }

        // Post threshold notification the first time the gate opens
        if previous < minimumCompletionPercent && currentProgressPercent >= minimumCompletionPercent {
            NotificationCenter.default.post(
                name: .wealthScanProgressDidReachMinimum,
                object: nil
            )
        }
    }

    /// Mark the scan as 100 % complete (e.g. called by the startup
    /// controller once `runUniverseScan()` finishes).
    ///
    /// Posts `wealthScanProgressDidReachMinimum` if the gate was not
    /// previously open so that any waiters are unblocked.
    func completeScan() {
        let previous = currentProgressPercent
        processedAssets = totalAssets
        currentProgressPercent = 100

        if previous < minimumCompletionPercent {
            NotificationCenter.default.post(
                name: .wealthScanProgressDidReachMinimum,
                object: nil
            )
        }

        WealthEventLogStore.shared.record(
            title: "Scan Progress",
            detail: "Scan complete – \(totalAssets) assets processed",
            category: "orchestration",
            tintName: "green",
            timestamp: .now
        )
    }

    /// Reset progress counters (e.g. after factory reset or sign-out).
    func reset() {
        totalAssets = 0
        processedAssets = 0
        currentProgressPercent = 0
    }

    // MARK: - Gate predicate

    /// `true` when scan progress has met or exceeded `minimumCompletionPercent`.
    ///
    /// The AI Live pipeline checks this gate before running the AI scan to
    /// avoid scoring an incomplete universe.  When `false`,
    /// `WealthDownstreamRebuildOrchestrator` runs a universe-scan pass
    /// first and only proceeds to the AI scan after the gate opens.
    var canAILiveProceed: Bool {
        currentProgressPercent >= minimumCompletionPercent
    }
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted on the main thread by `WealthScanProgressGate` the first time
    /// scan progress reaches `minimumCompletionPercent`.
    static let wealthScanProgressDidReachMinimum = Notification.Name(
        "WealthScanProgressDidReachMinimum"
    )
}
