import Foundation

// MARK: - WealthAIBrainCoordinator
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   `performAIScan()` in WealthEngineStore+Refresh.swift is an empty stub.
//   At the 10-minute and 20-minute soft timers, and at the 30-minute deep
//   timer, `runAIScan()` calls `performAIScan()` which does nothing.  Cards
//   never receive updated aiScore or confidence values after startup, so the
//   AI Live coordinator always sees stale or zero scores.
//
// Solution (new code only):
//   `WealthAIBrainCoordinator` is the **standard AI brain**.  It scores
//   every Opportunity in `rankedAssets` using metrics that are already
//   present on each card:
//
//     aiScore   = 100
//                 − earnings-risk penalty (linear above threshold 50)
//                 − macro-risk penalty    (linear above threshold 50)
//                 − anomaly penalty       (flat 20 pts when unstable)
//                 − execution penalty     (flat 15 pts when blocked)
//                 clamped to [1, 100]
//
//     confidence = base 50
//                 + 20 when execution is clean
//                 + 20 when anomaly is stable
//                 + 10 when data is fresh
//                 clamped to [0, 100]
//
//     aiRiskStance = "stable"   when aiScore ≥ 70
//                  = "cautious" when aiScore ≥ 45
//                  = "unstable" otherwise
//
//   Cards whose data is stale receive aiScore = 0 and confidence = 0 so
//   that downstream gates (AI Live, materialization re-check) correctly
//   exclude them.
//
// Relationship to the advanced brain:
//   `WealthAIBrainCoordinator` is the **standard brain** — it runs on
//   every scan cycle.  The **advanced brain** is
//   `WealthResearchFeedCoordinator`, which runs only at the 30-minute
//   deep-scan and augments the base aiScore with external research signals
//   (newsScore, researchSummary).
//
// Fixes:
//   Gap: performAIScan() was an empty stub — cards never received
//        aiScore/confidence updates from timer-based refreshes.

@MainActor
final class WealthAIBrainCoordinator {

    // MARK: Shared instance

    static let shared = WealthAIBrainCoordinator()
    private init() {}

    // MARK: - Scoring constants

    /// Base score before any risk discounts.
    private let baseScore: Int = 100

    /// earningsRisk values above this threshold start reducing the score.
    private let earningsRiskFloor: Int = 50

    /// macroRisk values above this threshold start reducing the score.
    private let macroRiskFloor: Int = 50

    /// Score deducted when `isAnomalyStable == false`.
    private let anomalyPenalty: Int = 20

    /// Score deducted when `isExecutionClean == false`.
    private let executionPenalty: Int = 15

    // MARK: - Public API

    /// Run the standard-brain scoring pass over all cards in `assets`.
    ///
    /// Each card receives an updated `aiScore`, `confidence`, and
    /// `aiRiskStance`.  Cards with stale data are zeroed so downstream
    /// gates reject them correctly.
    ///
    /// - Parameter assets: The engine's `rankedAssets` array, updated
    ///   in-place.  Pass `&WealthEngineStore.shared.rankedAssets` from
    ///   `performAIScan()`.
    func scoreAll(assets: inout [Opportunity]) {
        let before = assets.count
        assets = assets.map { brainScore($0) }

        let nonZero = assets.filter { $0.aiScore > 0 }.count

        WealthEventLogStore.shared.record(
            title: "AI Brain",
            detail: "Standard brain pass: \(before) cards → \(nonZero) scored (non-zero).",
            category: "ai-scan",
            tintName: nonZero == 0 ? "red" : "blue",
            timestamp: .now
        )
    }

    // MARK: - Private scoring

    /// Compute a new brain score for a single card and return a copy.
    private func brainScore(_ card: Opportunity) -> Opportunity {
        // Stale data → zero-out so AI Live and materialization recheck
        // correctly exclude this card.
        guard !card.isDataStale else {
            return card.withAIBrainScore(aiScore: 0, confidence: 0, aiRiskStance: "unstable")
        }

        // ── AI Score ──────────────────────────────────────────────────────
        var score = baseScore

        // Earnings-risk penalty: each point above the floor subtracts 0.5
        let earningsDelta = max(0, card.earningsRisk - earningsRiskFloor)
        score -= earningsDelta / 2

        // Macro-risk penalty: each point above the floor subtracts 0.33
        let macroDelta = max(0, card.macroRisk - macroRiskFloor)
        score -= macroDelta / 3

        if !card.isAnomalyStable { score -= anomalyPenalty   }
        if !card.isExecutionClean { score -= executionPenalty }

        let aiScore = max(1, min(100, score))

        // ── Confidence ────────────────────────────────────────────────────
        // Starts at 50 and climbs based on execution/anomaly/data quality.
        var confidence = 50
        if card.isExecutionClean { confidence += 20 }
        if card.isAnomalyStable  { confidence += 20 }
        confidence = max(0, min(100, confidence))

        // ── Risk Stance ───────────────────────────────────────────────────
        let riskStance: String
        if aiScore >= 70      { riskStance = "stable"   }
        else if aiScore >= 45 { riskStance = "cautious" }
        else                  { riskStance = "unstable" }

        return card.withAIBrainScore(aiScore: aiScore, confidence: confidence, aiRiskStance: riskStance)
    }
}

// MARK: - Opportunity+AIBrainScore
//
// Convenience builder that returns a copy of an Opportunity with updated
// brain-scoring fields.  Follows the same `withRank(_:)` pattern already
// used in `WealthEngineStore+Materialization.swift`.

extension Opportunity {

    /// Return a copy of this Opportunity with updated AI brain score fields.
    func withAIBrainScore(aiScore: Int, confidence: Int, aiRiskStance: String) -> Opportunity {
        var copy = self
        copy.aiScore      = aiScore
        copy.confidence   = confidence
        copy.aiRiskStance = aiRiskStance
        return copy
    }
}
