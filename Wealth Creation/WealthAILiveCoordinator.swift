import Foundation

// MARK: - WealthAILiveCoordinator
//
// AI Live Coordinator — base class declaration.
//
// ── Responsibility ───────────────────────────────────────────────────────
//
//   WealthAILiveCoordinator owns the AI Live promotion pipeline: given the
//   current ranked market cards it decides which cards to promote as "live
//   picks" and surfaces them to the Activity admission layer.
//
// ── Architecture ─────────────────────────────────────────────────────────
//
//   The coordinator is split across four files to keep each concern under
//   the project's 500-line limit:
//
//   • WealthAILiveCoordinator.swift     — this file: class declaration +
//                                         shared state
//   • WealthAILiveCoordinator+Evaluation.swift
//                                       — evaluate(), livePicks(),
//                                         liveValidation() static methods
//   • WealthAILiveCoordinator+Models.swift
//                                       — WealthAILivePromotion,
//                                         WealthAILiveIntakeCondition,
//                                         intakeConditions(for:)
//   • WealthAILiveCoordinator+Selection.swift
//                                       — primarySelection, topSelections(),
//                                         isPromoted(symbol:), promotedCard(for:)
//
// ── Pipeline rules ───────────────────────────────────────────────────────
//
//   IMPORTANT: The AI Live layer performs 75% risk re-validation ONLY.
//   It does NOT apply aiScore gates, rank-tier gates, or confidence gates.
//   Those decisions belong exclusively to WealthEngineStore+Materialization.
//
//   Forbidden in AI Live: aiScore threshold, rank > N threshold, confidence
//   threshold.  Any such gate must be removed.
//
//   The only gate AI Live may apply:
//     • isMarketExecutableCandidate == true   (passed to Activity)
//     • 75% risk re-validation               (earningsRisk / macroRisk)
//
// ── Threading ────────────────────────────────────────────────────────────
//
//   All methods run on @MainActor.  The `shared` singleton is accessed
//   from @MainActor call-sites only (WealthEngineStore, WealthNewComponents
//   Bootstrap, WealthNewComponentsBootstrap post-ready pipeline).
//
// ── Promoted cards ───────────────────────────────────────────────────────
//
//   `promotedCards` is the output of `evaluateCandidates()`.  It is a
//   filtered subset of the current market cards that passed the 75% risk
//   re-validation pass.  Downstream consumers (Activity admission, Order
//   Restriction audit, compact card view) read from this property.
//
//   After every rebuild `WealthNewComponentsBootstrap.runPostReadyPipeline()`
//   calls `evaluateCandidates()` so `promotedCards` is always current.

@MainActor
final class WealthAILiveCoordinator {

    // MARK: - Shared instance

    static let shared = WealthAILiveCoordinator()
    private init() {}

    // MARK: - State

    /// Cards that have passed the 75% risk re-validation pass and are
    /// currently promoted as AI Live picks.
    ///
    /// Set by `evaluateCandidates()`.  Empty until the first evaluation
    /// pass has completed after startup.
    private(set) var promotedCards: [Opportunity] = []

    // MARK: - Evaluation entry-point

    /// Run the AI Live evaluation pass against the current market cards.
    ///
    /// Reads `WealthEngineStore.shared.rankedAssets`, applies the 75% risk
    /// re-validation filter, and writes the result to `promotedCards`.
    ///
    /// Called by `WealthNewComponentsBootstrap.runPostReadyPipeline()` after
    /// every successful downstream rebuild.
    func evaluateCandidates() {
        let engine      = WealthEngineStore.shared
        let marketCards = engine.rankedAssets.filter { $0.rank > 0 }

        promotedCards = marketCards.filter { opp in
            opp.earningsRisk < SafeguardThreshold.earningsRisk &&
            opp.macroRisk    < SafeguardThreshold.macroRisk
        }

        WealthEventLogStore.shared.record(
            title: "AI Live Coordinator",
            detail: "evaluateCandidates: \(marketCards.count) market → \(promotedCards.count) promoted.",
            category: "ai",
            tintName: promotedCards.isEmpty ? "orange" : "green",
            timestamp: .now
        )
    }
}
