import Foundation

// MARK: - WealthActivityAdmissionAudit
//
// NEW audit-only code.  Does NOT modify any existing functions or logic.
//
// Problem addressed:
//   Even after AI Live promotes cards, Activity can reject them for multiple
//   reasons (cash gate, rebuy gate, timing, execution readiness, queue rules).
//   No instrumentation previously existed to explain why Activity stays at 0.
//
// Solution (new code only):
//   `WealthActivityAdmissionAuditReport` captures per-gate rejection counts.
//   `WealthActivityAdmissionAudit.runAudit(on:)` checks each observable
//   blocking condition on every AI-Live-promoted card so operators can see
//   exactly where the admissions funnel collapses.
//
//   Some gates (spendable cash, rebuy limit, session timing) depend on
//   runtime broker or session state that is not exposed as Opportunity
//   properties.  These are tracked as `requiresBrokerStateCount` and
//   `requiresSessionStateCount` so the audit accurately reports how many
//   cards need live data to evaluate.
//
// Fixes:
//   Error #10 – Activity Admission Audit

// MARK: - Report

/// Per-gate rejection counts for the Activity admission funnel.
struct WealthActivityAdmissionAuditReport {

    // ── Input ──────────────────────────────────────────────────────────

    /// AI Live promoted cards that were passed into the Activity admission check.
    let aiLiveCardsIn: Int

    // ── Observable gate failures ───────────────────────────────────────

    /// Cards with `isMarketExecutableCandidate == false`.
    /// These will fail the execution-readiness gate in Activity before
    /// any cash or timing check is evaluated.
    let executionReadinessFailures: Int

    /// Cards whose data is stale (`isDataStale == true`).  Activity
    /// applies a freshness check before admitting cards to the queue.
    let staleDataFailures: Int

    /// Cards flagged with an unstable anomaly signal that would prevent
    /// queue submission.
    let anomalyBlockedCount: Int

    // ── Runtime-dependent gates (cannot be evaluated from model alone) ─

    /// Cards whose admission outcome depends on available spendable cash or
    /// position sizing rules that require live broker state.  These cannot
    /// be audited purely from the `Opportunity` model.
    let requiresBrokerStateCount: Int

    /// Cards whose outcome depends on session timing (market open/close,
    /// trading-hours window) or rebuy-gate rules that require live session
    /// state.  These cannot be audited purely from the `Opportunity` model.
    let requiresSessionStateCount: Int

    // ── Output ─────────────────────────────────────────────────────────

    /// Cards that passed all observable checks and are estimated to be
    /// eligible for Activity admission (subject to broker/session gating).
    let estimatedAdmissibleCount: Int

    // ── Derived summaries ──────────────────────────────────────────────

    var dropSummary: String {
        """
        Activity Admission Audit
        AI Live cards in            : \(aiLiveCardsIn)
        Execution not ready         : \(executionReadinessFailures)
        Stale data                  : \(staleDataFailures)
        Anomaly blocked             : \(anomalyBlockedCount)
        Needs broker state (cash/rebuy): \(requiresBrokerStateCount)
        Needs session state (timing) : \(requiresSessionStateCount)
        Estimated admissible        : \(estimatedAdmissibleCount)
        """
    }
}

// MARK: - Audit runner

@MainActor
final class WealthActivityAdmissionAudit {

    // MARK: Shared instance

    static let shared = WealthActivityAdmissionAudit()
    private init() {}

    // MARK: State

    private(set) var lastReport: WealthActivityAdmissionAuditReport?

    // MARK: - Public API

    /// Inspect `promotedCards` (the output of the AI Live pass) against
    /// observable Activity admission gates.
    ///
    /// - Parameter promotedCards: Cards promoted by the AI Live evaluation.
    /// - Returns: A fully-populated `WealthActivityAdmissionAuditReport`.
    @discardableResult
    func runAudit(on promotedCards: [Opportunity]) -> WealthActivityAdmissionAuditReport {

        var executionNotReady     = 0
        var staleData             = 0
        var anomalyBlocked        = 0
        var needsBrokerState      = 0
        var needsSessionState     = 0
        var estimatedAdmissible   = 0

        for card in promotedCards {
            var cardRejected = false

            // Execution-readiness gate (permission / shares / cost)
            if !card.isMarketExecutableCandidate {
                executionNotReady += 1
                cardRejected = true
            }

            // Data-quality/freshness gate
            if card.isDataStale {
                staleData += 1
                cardRejected = true
            }

            // Anomaly/event-risk gate
            if !card.isAnomalyStable {
                anomalyBlocked += 1
                cardRejected = true
            }

            // Spendable cash and rebuy gates depend on live broker state.
            // We cannot evaluate them from the Opportunity model alone, so
            // count every card that otherwise passed as "needs broker state".
            // This gives the operator the upper-bound count that live gating
            // will subsequently reduce.
            if !cardRejected {
                needsBrokerState += 1
            }

            // Session/open timing and queue/submit rules depend on live
            // session state.  Same approach – count as "needs session state"
            // once all static gates pass.
            if !cardRejected {
                needsSessionState += 1
            }

            if !cardRejected {
                estimatedAdmissible += 1
            }
        }

        let report = WealthActivityAdmissionAuditReport(
            aiLiveCardsIn:             promotedCards.count,
            executionReadinessFailures: executionNotReady,
            staleDataFailures:         staleData,
            anomalyBlockedCount:       anomalyBlocked,
            requiresBrokerStateCount:  needsBrokerState,
            requiresSessionStateCount: needsSessionState,
            estimatedAdmissibleCount:  estimatedAdmissible
        )

        lastReport = report

        WealthEventLogStore.shared.record(
            title: "Activity Admission Audit",
            detail: report.dropSummary,
            category: "audit",
            tintName: estimatedAdmissible == 0 ? "red" : "green",
            timestamp: .now
        )

        return report
    }
}
