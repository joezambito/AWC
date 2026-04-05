import Foundation

// MARK: - WealthEngineStore+Materialization
//
// Market ranking engine and safeguard gate.
//
// Card lifecycle enforced here:
//
//   Scored Opportunities
//       ↓
//   GREEN CARDS CHECK  (WealthCardHoldingRouter)
//   ├─ Strong Green (P/L ≥ 0) ──────────────────────────────────────┐
//   ├─ Weak Green   (P/L < 0) → BLUE (waiting)                      │
//   └─ Fail → RED / GREY                                            │
//                                                                    ↓
//                                                    SAFEGUARD GATE (reject if):
//                                                    ├─ earningsRisk ≥ 70
//                                                    ├─ macroRisk    ≥ 75
//                                                    ├─ dataQuality  STALE
//                                                    ├─ executionState NOT CLEAN
//                                                    └─ anomalyState  NOT STABLE
//                                                                    ↓
//                                                    MARKET RANKING
//                                                    (top 100 executable greens)
//                                                    (50 % re-check on data/score)
//                                                    (assign rank 1, 1, 2, 3, 3 …)
//                                                                    ↓
//                                                    Only RANKED cards can proceed
//                                                    to AI Live Evaluation → Activity

// MARK: - Safeguard thresholds

private enum SafeguardThreshold {
    static let earningsRisk: Int = 70
    static let macroRisk:    Int = 75
}

// MARK: - WealthCardSafeguardResult

enum WealthCardSafeguardResult {
    case pass
    case rejected(reason: WealthCardRejectionReason)
}

enum WealthCardRejectionReason: String, CustomStringConvertible {
    case earningsRisk    = "earningsRisk"
    case macroRisk       = "macroRisk"
    case staleData       = "staleData"
    case executionBlock  = "executionBlock"
    case anomalyUnstable = "anomalyUnstable"

    var description: String { rawValue }
}

// MARK: - WealthEngineStore+Materialization

extension WealthEngineStore {

    // MARK: - Public entry-point

    /// Apply the market preparation pipeline to `rankedAssets`:
    ///   1. Route green cards through the safeguard gate.
    ///   2. Collect the top-100 executable greens that pass all checks.
    ///   3. Apply a 50 % data/score re-check.
    ///   4. Assign market ranks (multiple cards may share rank 1).
    ///   5. Publish the result so downstream consumers (Activity, Live Eval)
    ///      can proceed.
    ///
    /// No card reaches Activity without first passing this gate.
    @MainActor
    func materializeMarketCandidates() {
        guard !isMarketMaterializationInFlight else { return }
        isMarketMaterializationInFlight = true

        defer { isMarketMaterializationInFlight = false }

        let routed = WealthCardHoldingRouter.routeFromGreenCheckpoint(rankedAssets)
        let candidates = selectExecutableCandidates(from: routed.greenCards)
        let recheckPassed = applyDataRecheck(to: candidates)

        // Validate that all re-checked candidates are still market-executable
        // BEFORE applying ranks, so we fail fast and avoid propagating corrupt data.
        if !recheckPassed.allSatisfy(\.isMarketExecutableCandidate) {
            WealthEventLogStore.shared.record(
                title: "Pipeline Rejected",
                detail: "Non-executable card leaked into Market after materialization.",
                category: "materialization",
                tintName: "red",
                timestamp: .now
            )
#if DEBUG
            assertionFailure("Non-executable card leaked into Market during materialization")
#endif
            return
        }

        let ranked = assignMarketRanks(to: recheckPassed)

        WealthAllCardsStore.shared.sync(
            opportunities: rankedAssets,
            activityKeys: [],
            holdingKeys: Set(holdings.map(\.symbol)),
            livePickKeys: [],
            refreshTime: lastRefresh
        )
    }

    // MARK: - Safeguard gate

    /// Evaluate all safeguard rules for a single card.
    /// Returns `.pass` only when every rule is satisfied.
    func evaluateSafeguards(for opportunity: Opportunity) -> WealthCardSafeguardResult {
        if opportunity.earningsRisk >= SafeguardThreshold.earningsRisk {
            return .rejected(reason: .earningsRisk)
        }
        if opportunity.macroRisk >= SafeguardThreshold.macroRisk {
            return .rejected(reason: .macroRisk)
        }
        if opportunity.isDataStale {
            return .rejected(reason: .staleData)
        }
        if !opportunity.isExecutionClean {
            return .rejected(reason: .executionBlock)
        }
        if !opportunity.isAnomalyStable {
            return .rejected(reason: .anomalyUnstable)
        }
        return .pass
    }

    // MARK: - Private pipeline helpers

    /// Filter `greenCards` to only those that:
    ///   a) pass the safeguard gate, and
    ///   b) are marked as market-executable candidates.
    /// Returns at most `WealthAllCardsStore.marketCardLimit` (100) cards.
    private func selectExecutableCandidates(from greenCards: [Opportunity]) -> [Opportunity] {
        greenCards
            .filter { evaluateSafeguards(for: $0) == .pass }
            .filter(\.isMarketExecutableCandidate)
            .prefix(WealthAllCardsStore.marketCardLimit)
            .map { $0 }
    }

    /// 50 % data/score re-check: remove cards whose AI score or data
    /// quality has degraded since the last full scan.
    private func applyDataRecheck(to candidates: [Opportunity]) -> [Opportunity] {
        candidates.filter { opportunity in
            guard !opportunity.isDataStale else { return false }
            guard opportunity.aiScore > 0 else { return false }
            return true
        }
    }

    /// Assign integer market ranks to a pre-sorted list of candidates.
    /// Cards sharing the same `marketQualityTier` receive the same rank
    /// (dense ranking: 1, 1, 2, 3, 3, …).
    private func assignMarketRanks(to candidates: [Opportunity]) -> [Opportunity] {
        var currentTier: WealthMarketQualityTier?
        var tierRank = 0

        return candidates.map { opportunity in
            let tier = opportunity.marketQualityTier
            if tier != currentTier {
                currentTier = tier
                tierRank += 1
            }
            return opportunity.withRank(tierRank)
        }
    }
}

// MARK: - Equatable conformance for WealthCardSafeguardResult

extension WealthCardSafeguardResult: Equatable {
    static func == (lhs: WealthCardSafeguardResult, rhs: WealthCardSafeguardResult) -> Bool {
        switch (lhs, rhs) {
        case (.pass, .pass):
            return true
        case (.rejected(let l), .rejected(let r)):
            return l == r
        default:
            return false
        }
    }
}
