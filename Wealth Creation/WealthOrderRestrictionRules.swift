import Foundation

// MARK: - WealthOrderRestrictionRules
//
// NEW audit-only code.  Does NOT modify any existing functions or logic.
//
// Problem addressed:
//   Activity can silently reject cards that passed AI Live promotion because
//   of order-restriction rules (market closed, new orders disabled, rebuy
//   gate, queue limits, etc.).  No instrumentation previously existed to
//   explain these rejections.
//
// Solution (new code only):
//   `WealthOrderRestrictionAuditReport` captures per-rule restriction counts.
//   `WealthOrderRestrictionRules.runAudit(on:)` inspects every AI Live
//   promoted card against the observable order-restriction conditions and
//   returns a count-only report.  The actual order submission logic is
//   unchanged.
//
// Fixes:
//   Problem #8 – Activity starvation: order restriction rules not audited

// MARK: - Report

struct WealthOrderRestrictionAuditReport {

    // ── Input ──────────────────────────────────────────────────────────

    /// AI Live promoted cards passed into the order-restriction check.
    let candidatesIn: Int

    // ── Observable restriction counts ─────────────────────────────────

    /// Cards that would be blocked by the kill switch (global trading halt).
    /// Tracked as a static flag from `WealthEngineStore.shared`.
    let killSwitchBlockedCount: Int

    /// Cards that fail the execution-readiness check after promotion.
    /// A card can become non-executable between AI Live evaluation and
    /// order submission (e.g. a holding was opened in between).
    let executionReadinessLostCount: Int

    // ── Runtime-dependent restrictions (cannot be evaluated from model) ─

    /// Cards whose admission depends on the market session being open
    /// (cannot be evaluated from the `Opportunity` model alone).
    let requiresMarketOpenCount: Int

    /// Cards that require a cash/position-sizing check that depends on
    /// live broker state (spendable cash, existing holdings).
    let requiresCashCheckCount: Int

    /// Cards that might be gated by the rebuy lock-out rule.
    let requiresRebuyCheckCount: Int

    // ── Output ─────────────────────────────────────────────────────────

    /// Cards that passed all observable checks and are estimated to be
    /// submittable (subject to market-open and cash gating).
    let estimatedSubmittableCount: Int

    // ── Derived summaries ──────────────────────────────────────────────

    var dropSummary: String {
        """
        Order Restriction Audit
        Candidates in              : \(candidatesIn)
        Kill switch blocked        : \(killSwitchBlockedCount)
        Execution readiness lost   : \(executionReadinessLostCount)
        Needs market-open check    : \(requiresMarketOpenCount)
        Needs cash check           : \(requiresCashCheckCount)
        Needs rebuy check          : \(requiresRebuyCheckCount)
        Estimated submittable      : \(estimatedSubmittableCount)
        """
    }
}

// MARK: - Audit runner

@MainActor
final class WealthOrderRestrictionRules {

    // MARK: Shared instance

    static let shared = WealthOrderRestrictionRules()
    private init() {}

    // MARK: State

    private(set) var lastReport: WealthOrderRestrictionAuditReport?

    // MARK: - Public API

    /// Inspect `promotedCards` against observable order-restriction conditions
    /// and return a count-only audit report.
    ///
    /// - Parameter promotedCards: Cards output by the AI Live evaluation pass.
    /// - Returns: A fully-populated `WealthOrderRestrictionAuditReport`.
    @discardableResult
    func runAudit(on promotedCards: [Opportunity]) -> WealthOrderRestrictionAuditReport {

        var killSwitchBlocked      = 0
        var executionReadinessLost = 0
        var requiresMarketOpen     = 0
        var requiresCash           = 0
        var requiresRebuy          = 0
        var estimatedSubmittable   = 0

        // Read the global kill switch once.
        let killSwitchActive = WealthEngineStore.shared.killSwitch

        for card in promotedCards {
            var cardBlocked = false

            // Kill switch: global trading halt
            if killSwitchActive {
                killSwitchBlocked += 1
                cardBlocked = true
            }

            // Execution readiness: card may have become non-executable
            // between AI Live evaluation and this audit.
            if !card.isMarketExecutableCandidate {
                executionReadinessLost += 1
                cardBlocked = true
            }

            // Runtime gates that cannot be evaluated from the model alone
            if !cardBlocked {
                requiresMarketOpen += 1
                requiresCash       += 1
                requiresRebuy      += 1
                estimatedSubmittable += 1
            }
        }

        let report = WealthOrderRestrictionAuditReport(
            candidatesIn:              promotedCards.count,
            killSwitchBlockedCount:    killSwitchBlocked,
            executionReadinessLostCount: executionReadinessLost,
            requiresMarketOpenCount:   requiresMarketOpen,
            requiresCashCheckCount:    requiresCash,
            requiresRebuyCheckCount:   requiresRebuy,
            estimatedSubmittableCount: estimatedSubmittable
        )

        lastReport = report

        WealthEventLogStore.shared.record(
            title: "Order Restriction Audit",
            detail: report.dropSummary,
            category: "audit",
            tintName: estimatedSubmittable == 0 ? "red" : "green",
            timestamp: .now
        )

        return report
    }
}
