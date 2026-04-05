import Foundation

// MARK: - WealthAILiveCoordinator
//
// NEW code only.  Does NOT modify any existing functions.
//
// Coordinates the AI Live evaluation pass: determines which Market-ranked
// cards are eligible for AI Live promotion given the current scan progress
// and card quality state.

@MainActor
final class WealthAILiveCoordinator {

    // MARK: Shared instance

    static let shared = WealthAILiveCoordinator()
    private init() {}

    // MARK: - Public state

    /// Cards currently promoted to AI Live (non-empty only after at least
    /// one evaluation pass has run at or above the scan-progress gate).
    private(set) var promotedCards: [Opportunity] = []

    /// Last time `evaluateCandidates()` ran to completion.
    private(set) var lastEvaluationDate: Date?
}

// MARK: - WealthAILiveCoordinator+Evaluation
//
// Problem addressed:
//   AI Live was promoting Market cards before the universe scan reached a
//   minimum completion level.  Cards evaluated at low scan-progress have
//   missing AI scores (all-zero), leading to stale promotion decisions and
//   empty Activity queues.
//
// Solution (new code only):
//   `evaluateCandidates()` reads `WealthEngineScanScheduler.currentProgress`
//   before evaluating any card.  If the progress has not reached
//   `minimumProgressForAILive` (default: 0.5, i.e. universe + AI scan done),
//   evaluation is skipped and an audit event is logged.
//
// Fixes:
//   Blocker #5 – Scan progress gate missing from AI Live visibility

extension WealthAILiveCoordinator {

    // MARK: - Evaluation entry-point

    /// Evaluate all market-ranked cards against the AI Live intake conditions
    /// and update `promotedCards` with the resulting set.
    ///
    /// Returns without evaluating if:
    ///   • Scan progress is below `minimumProgressForAILive`.
    ///   • The engine has no ranked assets.
    ///
    /// Safe to call from any context (always runs on `@MainActor`).
    func evaluateCandidates() {
        let scheduler = WealthEngineScanScheduler.shared

        // ── Scan-progress gate ────────────────────────────────────────────
        guard scheduler.hasReachedAILiveGate else {
            WealthEventLogStore.shared.record(
                title: "AI Live Coordinator",
                detail: "Evaluation skipped: scan progress \(String(format: "%.0f%%", scheduler.currentProgress * 100)) < minimum \(String(format: "%.0f%%", scheduler.minimumProgressForAILive * 100)).",
                category: "ai-live",
                tintName: "orange",
                timestamp: .now
            )
            return
        }

        let engine = WealthEngineStore.shared
        let marketCards = engine.rankedAssets.filter { $0.rank > 0 }

        guard !marketCards.isEmpty else {
            WealthEventLogStore.shared.record(
                title: "AI Live Coordinator",
                detail: "Evaluation skipped: no ranked market cards.",
                category: "ai-live",
                tintName: "orange",
                timestamp: .now
            )
            return
        }

        // ── Run the rejection audit (measurement only, no logic changes) ──
        WealthAILiveRejectionAudit.shared.runAudit(on: marketCards)

        // ── Promotion filter ──────────────────────────────────────────────
        // A card is eligible for AI Live promotion when it passes all
        // observable intake conditions.  The actual score-threshold check
        // is delegated to the Opportunity model (`aiScore > 0`).
        //
        // Thresholds mirror the safeguard gate in WealthEngineStore+Materialization:
        //   earningsRisk < SafeguardThreshold.earningsRisk (70)
        //   macroRisk    < SafeguardThreshold.macroRisk    (75)
        let earningsRiskLimit = SafeguardThreshold.earningsRisk
        let macroRiskLimit    = SafeguardThreshold.macroRisk

        let eligible = marketCards.filter { card in
            card.aiScore > 0
            && !card.isDataStale
            && card.isAnomalyStable
            && card.earningsRisk < earningsRiskLimit
            && card.macroRisk < macroRiskLimit
            && card.rank <= WealthAILiveRejectionAudit.shared.topTierRankThreshold
        }

        promotedCards    = eligible
        lastEvaluationDate = Date()

        // Persist to file-backed cache so the result survives app restart.
        WealthDownstreamCacheSanity.shared.saveAILiveResults(eligible)

        WealthEventLogStore.shared.record(
            title: "AI Live Coordinator",
            detail: "Evaluation complete: \(marketCards.count) market → \(eligible.count) promoted.",
            category: "ai-live",
            tintName: eligible.isEmpty ? "red" : "green",
            timestamp: .now
        )
    }

    /// `true` when `promotedCards` is non-empty.
    var hasPromotedCards: Bool {
        !promotedCards.isEmpty
    }
}
