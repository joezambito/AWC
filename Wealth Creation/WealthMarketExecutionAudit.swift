import Foundation

// MARK: - WealthMarketExecutionAudit
//
// NEW audit-only code.  Does NOT modify any existing functions or logic.
//
// Problem addressed:
//   The pipeline drops from 128 k universe cards to ~208 green and then to
//   ~42 Market cards.  No instrumentation previously existed to explain where
//   cards are lost at each gate.
//
// Solution (new code only):
//   `WealthMarketExecutionAuditReport` captures per-stage counts and
//   rejection reasons.
//   `WealthMarketExecutionAudit.runAudit(on:engine:)` walks the same gates
//   used by `materializeMarketCandidates()` (without changing them) and
//   tallies every rejection so operators can see the exact numbers.
//
// Fixes:
//   Error #8 – Market Execution-Readiness Audit

// MARK: - Report

/// A point-in-time snapshot of card counts at every market-preparation gate.
struct WealthMarketExecutionAuditReport {

    // ── Stage counts ─────────────────────────────────────────────────────

    /// Total opportunities in the scored universe.
    let universeCount: Int

    /// Opportunities with unrealizedPnL ≥ 0 (eligible for Market ranking).
    let strongGreenCount: Int

    /// Opportunities with unrealizedPnL < 0 (routed to Blue waiting list).
    let weakGreenCount: Int

    /// Per-reason rejection counts at the safeguard gate.
    ///
    /// Keys map to `WealthCardRejectionReason` raw values so the report
    /// stays Codable without adding a conformance to the existing enum.
    let safeguardRejectionCounts: [String: Int]

    /// Cards that passed the safeguard gate.
    let safeguardPassCount: Int

    /// Cards that passed safeguards but failed `isMarketExecutableCandidate`
    /// (encapsulates permission-not-go, recommendedShares ≤ 0, trueCost ≤ 0,
    /// and any other execution-readiness block).
    let executionBlockedCount: Int

    /// Final market candidate count (capped at `WealthAllCardsStore.marketCardLimit`).
    let marketCandidateCount: Int

    // ── Derived summaries ────────────────────────────────────────────────

    /// Total cards rejected by the safeguard gate across all reasons.
    var totalSafeguardRejected: Int {
        safeguardRejectionCounts.values.reduce(0, +)
    }

    /// Human-readable pipeline summary suitable for logging.
    var dropSummary: String {
        let rejDetail = safeguardRejectionCounts.isEmpty
            ? "none"
            : safeguardRejectionCounts
                .sorted { $0.value > $1.value }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")

        return """
        Market Execution Audit
        Universe            : \(universeCount)
        Strong Green (PnL≥0): \(strongGreenCount)
        Weak Green → Blue   : \(weakGreenCount)
        Safeguard rejected  : \(totalSafeguardRejected) [\(rejDetail)]
        Safeguard passed    : \(safeguardPassCount)
        Execution blocked   : \(executionBlockedCount)
        Market candidates   : \(marketCandidateCount)
        """
    }
}

// MARK: - Audit runner

@MainActor
final class WealthMarketExecutionAudit {

    // MARK: Shared instance

    static let shared = WealthMarketExecutionAudit()
    private init() {}

    // MARK: State

    /// The most recent audit report.  `nil` until `runAudit(on:engine:)` is
    /// called at least once.
    private(set) var lastReport: WealthMarketExecutionAuditReport?

    // MARK: - Public API

    /// Walk every market-preparation gate and return a count-only audit
    /// report without modifying any engine state.
    ///
    /// - Parameters:
    ///   - universe: The full scored opportunity set (`rankedAssets`).
    ///   - engine:   Engine instance used for safeguard evaluation
    ///               (defaults to `WealthEngineStore.shared`).
    /// - Returns: A fully-populated `WealthMarketExecutionAuditReport`.
    @discardableResult
    func runAudit(
        on universe: [Opportunity],
        engine: WealthEngineStore = .shared
    ) -> WealthMarketExecutionAuditReport {

        // ── Stage 1 : Green check ─────────────────────────────────────────
        let strongGreen = universe.filter(\.isStrongGreen)
        let weakGreen   = universe.filter(\.isWeakGreen)

        // ── Stage 2 : Safeguard gate ──────────────────────────────────────
        var safeguardRejections: [String: Int] = [:]
        var safeguardPassed: [Opportunity] = []

        for card in strongGreen {
            switch engine.evaluateSafeguards(for: card) {
            case .pass:
                safeguardPassed.append(card)
            case .rejected(let reason):
                safeguardRejections[reason.rawValue, default: 0] += 1
            }
        }

        // ── Stage 3 : Execution-readiness gate ───────────────────────────
        // `isMarketExecutableCandidate` encapsulates the permission, share-
        // count, and cost checks that are evaluated inside WealthCore.swift.
        let executionBlocked = safeguardPassed.filter { !$0.isMarketExecutableCandidate }
        let executable       = safeguardPassed.filter(\.isMarketExecutableCandidate)

        let report = WealthMarketExecutionAuditReport(
            universeCount:            universe.count,
            strongGreenCount:         strongGreen.count,
            weakGreenCount:           weakGreen.count,
            safeguardRejectionCounts: safeguardRejections,
            safeguardPassCount:       safeguardPassed.count,
            executionBlockedCount:    executionBlocked.count,
            marketCandidateCount:     min(executable.count, WealthAllCardsStore.marketCardLimit)
        )

        lastReport = report

        WealthEventLogStore.shared.record(
            title: "Market Execution Audit",
            detail: report.dropSummary,
            category: "audit",
            tintName: "orange",
            timestamp: .now
        )

        return report
    }
}
