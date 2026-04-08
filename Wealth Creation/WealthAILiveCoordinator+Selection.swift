import Foundation

extension WealthAILiveCoordinator {
    static func selectPromotedKeys(
        from rankedCandidates: [EvaluatedCandidate],
        rankedResults: [String: WealthAILiveResult],
        holdingKeys: Set<String>,
        spendableCash: Double
    ) -> Set<String> {
        var selectedKeys: Set<String> = []
        _ = spendableCash

        for candidate in rankedCandidates {
            let key = candidate.result.key
            guard let result = rankedResults[key], result.aiLiveDecision == WealthAILiveDecision.promote else { continue }
            guard !holdingKeys.contains(key) else { continue }
            guard candidate.opportunity.orderState != OrderExecutionState.filled else { continue }

            selectedKeys.insert(key)
        }

        let promotedCandidates = rankedCandidates.filter { selectedKeys.contains($0.result.key) }
        let validRanks = promotedCandidates.map { $0.opportunity.rank }.filter { $0 > 0 }
        if let bestRank = validRanks.min() {
            return Set(promotedCandidates.filter { $0.opportunity.rank == bestRank }.map { $0.result.key })
        }

        return selectedKeys
    }

    static func rankingOrder(lhs: EvaluatedCandidate, rhs: EvaluatedCandidate) -> Bool {
        if lhs.opportunity.rank != rhs.opportunity.rank {
            return lhs.opportunity.rank < rhs.opportunity.rank
        }
        return lhs.opportunity.symbol.localizedStandardCompare(rhs.opportunity.symbol) == .orderedAscending
    }

    static func pairedReplacements(
        currentActivity: [Opportunity],
        replacedActivityKeys: Set<String>,
        newSelectedKeys: Set<String>,
        rankedResults: [String: WealthAILiveResult]
    ) -> [(String, String)] {
        let droppedActivity = currentActivity
            .filter { replacedActivityKeys.contains(WealthOpportunityLaneRules.laneKey($0)) }
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank > rhs.rank }
                return lhs.symbol.localizedStandardCompare(rhs.symbol) == .orderedDescending
            }

        let incomingWinners = newSelectedKeys
            .compactMap { key in rankedResults[key] }
            .sorted { lhs, rhs in
                return lhs.symbol.localizedStandardCompare(rhs.symbol) == .orderedAscending
            }

        let pairCount = min(droppedActivity.count, incomingWinners.count)
        guard pairCount > 0 else { return [] }

        return (0..<pairCount).map { index in
            let newKey = incomingWinners[index].key
            let oldKey = WealthOpportunityLaneRules.laneKey(droppedActivity[index])
            return (newKey, oldKey)
        }
    }
}
