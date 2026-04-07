import Foundation

extension WealthAILiveCoordinator {
    struct EvaluatedCandidate {
        let opportunity: Opportunity
        let result: WealthAILiveResult
    }

    @MainActor
    static func evaluate(
        opportunities: [Opportunity],
        currentActivity: [Opportunity],
        holdings: [Holding],
        spendableCash: Double,
        returnedFromActivity: [String: WealthActivityRefusalHandoff]
    ) -> WealthAILiveEvaluation {
        let holdingKeys = Set(holdings.map(WealthOpportunityLaneRules.laneKey))
        let currentActivityKeys = Set(currentActivity.map(WealthOpportunityLaneRules.laneKey))

        let rankedCandidates = opportunities
            .map {
                let key = WealthOpportunityLaneRules.laneKey($0)
                return EvaluatedCandidate(
                    opportunity: $0,
                    result: liveValidation(for: $0, returnedFromActivity: returnedFromActivity[key])
                )
            }
            .sorted(by: rankingOrder)

        var rankedResults = rankedCandidates.reduce(into: [String: WealthAILiveResult]()) { partialResult, candidate in
            partialResult[candidate.result.key] = candidate.result
        }

        let selectedKeys = selectPromotedKeys(
            from: rankedCandidates,
            rankedResults: rankedResults,
            holdingKeys: holdingKeys,
            spendableCash: spendableCash
        )

        let replacedActivityKeys = currentActivityKeys.subtracting(selectedKeys)
        let newSelectedKeys = selectedKeys.subtracting(currentActivityKeys)
        let replacementPairs = pairedReplacements(
            currentActivity: currentActivity,
            replacedActivityKeys: replacedActivityKeys,
            newSelectedKeys: newSelectedKeys,
            rankedResults: rankedResults
        )
        let replacementByNewKey = replacementPairs.reduce(into: [String: String]()) { partialResult, pair in
            partialResult[pair.0] = pair.1
        }
        let replacedByOldKey = replacementPairs.reduce(into: [String: String]()) { partialResult, pair in
            partialResult[pair.1] = pair.0
        }

        if !replacementByNewKey.isEmpty {
            for key in newSelectedKeys {
                guard replacementByNewKey[key] != nil else { continue }
                if let current = rankedResults[key] {
                    rankedResults[key] = current.with(
                        decision: WealthAILiveDecision.replaceExisting,
                        reason: "\(current.reason) Promoted over a weaker current Activity card by Market rank."
                    )
                }
            }
        }

        return WealthAILiveEvaluation(
            resultsByKey: rankedResults,
            promotedKeys: selectedKeys,
            replacedActivityKeys: replacedActivityKeys,
            replacementByNewKey: replacementByNewKey,
            replacedByOldKey: replacedByOldKey
        )
    }

    @MainActor
    static func livePicks(
        from opportunities: [Opportunity],
        aiLiveResults: [String: WealthAILiveResult],
        activityKeys: Set<String>,
        holdingKeys: Set<String>,
        spendableCash: Double
    ) -> [Opportunity] {
        _ = spendableCash
        var selected: [Opportunity] = []

        let sorted = opportunities.sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.symbol.localizedStandardCompare(rhs.symbol) == .orderedAscending
        }

        for opportunity in sorted {
            let key = WealthOpportunityLaneRules.laneKey(opportunity)
            guard let result = aiLiveResults[key], result.allowsActivityPromotion else { continue }
            guard opportunity.rank > 0 else { continue }
            guard opportunity.hasFreshPromotionRefresh else { continue }
            guard !activityKeys.contains(key) else { continue }
            guard !holdingKeys.contains(key) else { continue }
            guard opportunity.orderState != OrderExecutionState.filled else { continue }

            selected.append(opportunity)
        }

        return selected
    }

    fileprivate static func liveValidation(
        for opportunity: Opportunity,
        returnedFromActivity handoff: WealthActivityRefusalHandoff?
    ) -> WealthAILiveResult {
        var reasons: [String] = []

        if let handoff {
            reasons.append("\(handoff.state.rawValue): \(handoff.reason)")
        }

        if opportunity.rank <= 0 {
            reasons.append("Market rank is missing")
        }

        if !opportunity.hasFreshPromotionRefresh {
            reasons.append("Latest Market refresh is too old for AI Live promotion")
        }

        if opportunity.orderState == .filled {
            reasons.append("Order is already filled")
        }

        if opportunity.dataQualityLabel.uppercased() == "AGING" {
            reasons.append("Data quality is aging")
        } else if opportunity.dataQualityLabel.uppercased() == "STALE" {
            reasons.append("Data quality is stale")
        }

        if opportunity.earningsEventRisk >= 70 {
            reasons.append("Earnings event risk is elevated")
        }

        if opportunity.macroEventRisk >= 75 {
            reasons.append("Macro event risk is elevated")
        }

        if opportunity.advancedSignal.anomalyState != "STABLE" {
            reasons.append("Live anomaly signal is elevated (noted, not blocking)")
        }

        if opportunity.advancedSignal.executionState != "EXECUTION CLEAN" {
            reasons.append("Execution quality is no longer clean (noted, not blocking)")
        }

        if let readinessReason = opportunity.executionReadiness.reason {
            reasons.append(readinessReason)
        }

        // Only market rank, data freshness, order state, and data quality gate AI Live.
        // AI score and confidence do NOT restrict promotion — only ranking (assigned by Market) is authoritative.
        // Exception: spiker and event-risk signals detected by data are respected.
        let decision: WealthAILiveDecision
        if opportunity.rank <= 0 ||
            !opportunity.hasFreshPromotionRefresh ||
            opportunity.orderState == .filled ||
            !opportunity.isExecutionEligible ||
            opportunity.dataQualityLabel.uppercased() == "STALE" ||
            opportunity.earningsEventRisk >= 70 ||
            opportunity.macroEventRisk >= 75 {
            decision = .reject
        } else {
            decision = .promote
        }

        let reason: String
        if reasons.isEmpty {
            reason = "AI Live accepted the card using Market rank as authority."
        } else if decision == .promote {
            reason = "Market rank remained valid. \(reasons.joined(separator: " "))"
        } else {
            reason = reasons.joined(separator: " ")
        }

        return WealthAILiveResult(
            key: WealthOpportunityLaneRules.laneKey(opportunity),
            symbol: opportunity.symbol,
            market: opportunity.market,
            aiLiveDecision: decision,
            reason: reason,
            activityReturnState: handoff?.state,
            activityReturnReason: handoff?.reason
        )
    }
}
