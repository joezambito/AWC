import Foundation

// MARK: - WealthAILiveRejectionAudit
//
// NEW audit-only code.  Does NOT modify any existing functions or logic.
//
// Problem addressed:
//   Even with ~42 Market cards present, AI Live can shrink to zero because
//   of stale data, missing AI scores, anomaly flags, and high event-risk.
//   No instrumentation previously existed to explain the shrinkage.
//
// Solution (new code only):
//   `WealthAILiveRejectionAuditReport` captures per-reason rejection counts.
//   `WealthAILiveRejectionAudit.runAudit(on:)` inspects every market-ranked
//   card against the same properties used by the AI Live evaluation pass so
//   operators can see exactly which conditions cause candidate starvation.
//
// Fixes:
//   Error #9 – AI Live Candidate Starvation Audit

// MARK: - Report

/// Counts for each category of AI Live intake rejection.
struct WealthAILiveRejectionAuditReport {

    // ── Input ──────────────────────────────────────────────────────────

    /// Number of market-ranked cards passed into the AI Live evaluation.
    let marketCardsIn: Int

    // ── Per-reason rejection counts ────────────────────────────────────

    /// Cards with `aiScore == 0` – never evaluated or score lost after
    /// restart.  These cards have no basis for AI Live promotion.
    let zeroAIScoreCount: Int

    /// Cards whose `dataQualityLabel` is flagged as stale, making their
    /// promotion scores unreliable (stale-promotion-freshness rejection).
    let stalePromotionFreshnessCount: Int

    /// Cards not at the top quality tier (`rank > topTierRankThreshold`).
    /// AI Live uses a top-tier-only intake filter to avoid flooding the
    /// live queue with lower-confidence candidates.
    let lowTierIntakeCount: Int

    /// Cards with an unstable anomaly signal (`aiRiskStance` contains
    /// "unstable") – these are excluded by the anomaly/event-risk gate.
    let anomalyRejectionCount: Int

    /// Cards whose earnings-event risk score exceeds the safeguard threshold
    /// (earningsRisk ≥ 70).  AI Live applies the same threshold as the
    /// safeguard gate when re-evaluating freshness on each cycle.
    let highEarningsRiskCount: Int

    /// Cards whose macro-event risk score exceeds the safeguard threshold
    /// (macroRisk ≥ 75).
    let highMacroRiskCount: Int

    /// Cards that pass all of the above checks and are considered eligible
    /// for AI Live promotion.
    let estimatedEligibleCount: Int

    // ── Thresholds (informational) ─────────────────────────────────────

    /// Rank threshold above which a card is considered non-top-tier.
    let topTierRankThreshold: Int

    // ── Derived summaries ──────────────────────────────────────────────

    var dropSummary: String {
        """
        AI Live Rejection Audit
        Market cards in         : \(marketCardsIn)
        Zero AI score           : \(zeroAIScoreCount)
        Stale promotion data    : \(stalePromotionFreshnessCount)
        Low tier (rank > \(topTierRankThreshold))    : \(lowTierIntakeCount)
        Anomaly unstable        : \(anomalyRejectionCount)
        High earnings risk ≥70  : \(highEarningsRiskCount)
        High macro risk ≥75     : \(highMacroRiskCount)
        Estimated eligible      : \(estimatedEligibleCount)
        """
    }
}

// MARK: - Audit runner

@MainActor
final class WealthAILiveRejectionAudit {

    // MARK: Shared instance

    static let shared = WealthAILiveRejectionAudit()
    private init() {}

    // MARK: Configuration

    /// Cards with `rank` strictly greater than this value are treated as
    /// non-top-tier and counted in `lowTierIntakeCount`.
    ///
    /// Adjust this value to match the actual AI Live top-tier cutoff in
    /// WealthCore.swift when that implementation is available.
    var topTierRankThreshold: Int = 3

    // MARK: State

    private(set) var lastReport: WealthAILiveRejectionAuditReport?

    // MARK: - Public API

    /// Inspect `marketCards` against the known AI Live intake conditions
    /// and return a per-reason rejection count report.
    ///
    /// - Parameter marketCards: The ranked market cards produced by
    ///   `materializeMarketCandidates()`.
    /// - Returns: A fully-populated `WealthAILiveRejectionAuditReport`.
    @discardableResult
    func runAudit(on marketCards: [Opportunity]) -> WealthAILiveRejectionAuditReport {

        var zeroAIScore           = 0
        var stalePromotion        = 0
        var lowTier               = 0
        var anomalyRejected       = 0
        var highEarningsRisk      = 0
        var highMacroRisk         = 0
        var eligible              = 0

        for card in marketCards {
            var cardRejected = false

            // Zero AI score → promotion score unavailable
            if card.aiScore == 0 {
                zeroAIScore += 1
                cardRejected = true
            }

            // Stale data → promotion freshness gate
            if card.isDataStale {
                stalePromotion += 1
                cardRejected = true
            }

            // Low tier → top-tier-only intake filter
            if card.rank > topTierRankThreshold {
                lowTier += 1
                cardRejected = true
            }

            // Anomaly unstable → event-risk gate
            if !card.isAnomalyStable {
                anomalyRejected += 1
                cardRejected = true
            }

            // High earnings risk → event-risk gate (threshold mirrors safeguard)
            if card.earningsRisk >= SafeguardThreshold.earningsRisk {
                highEarningsRisk += 1
                cardRejected = true
            }

            // High macro risk → event-risk gate
            if card.macroRisk >= SafeguardThreshold.macroRisk {
                highMacroRisk += 1
                cardRejected = true
            }

            if !cardRejected {
                eligible += 1
            }
        }

        let report = WealthAILiveRejectionAuditReport(
            marketCardsIn:               marketCards.count,
            zeroAIScoreCount:            zeroAIScore,
            stalePromotionFreshnessCount: stalePromotion,
            lowTierIntakeCount:          lowTier,
            anomalyRejectionCount:       anomalyRejected,
            highEarningsRiskCount:       highEarningsRisk,
            highMacroRiskCount:          highMacroRisk,
            estimatedEligibleCount:      eligible,
            topTierRankThreshold:        topTierRankThreshold
        )

        lastReport = report

        WealthEventLogStore.shared.record(
            title: "AI Live Rejection Audit",
            detail: report.dropSummary,
            category: "audit",
            tintName: eligible == 0 ? "red" : "yellow",
            timestamp: .now
        )

        return report
    }
}
