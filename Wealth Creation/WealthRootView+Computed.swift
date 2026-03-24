import SwiftUI

enum WealthOpportunityLaneRules {
    nonisolated static func laneKey(symbol: String, market: String) -> String {
        "\(symbol.uppercased())-\(market.uppercased())"
    }

    nonisolated static func laneKey(_ opportunity: Opportunity) -> String {
        laneKey(symbol: opportunity.symbol, market: opportunity.market)
    }

    nonisolated static func laneKey(_ holding: Holding) -> String {
        laneKey(symbol: holding.symbol, market: holding.market)
    }

    static func rankedUniverse(from opportunities: [Opportunity]) -> [Opportunity] {
        opportunities.sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            if lhs.aiScore != rhs.aiScore { return lhs.aiScore < rhs.aiScore }
            if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
            return lhs.symbol.localizedStandardCompare(rhs.symbol) == .orderedAscending
        }
    }

    static func livePicks(
        from opportunities: [Opportunity],
        activityKeys: Set<String>,
        holdingKeys: Set<String>,
        spendableCash: Double
    ) -> [Opportunity] {
        var remainingCash = max(0, spendableCash)
        var selected: [Opportunity] = []

        for opportunity in rankedUniverse(from: opportunities) {
            let key = laneKey(opportunity)

            guard !activityKeys.contains(key) else { continue }
            guard !holdingKeys.contains(key) else { continue }
            guard opportunity.orderState != .filled else { continue }
            guard opportunity.isGreenBuyReady else { continue }
            guard opportunity.recommendedShares > 0 else { continue }
            guard opportunity.trueCost > 0 else { continue }
            guard opportunity.trueCost <= remainingCash else { continue }

            selected.append(opportunity)
            remainingCash = max(0, remainingCash - opportunity.trueCost)
        }

        return selected
    }

    static func marketLane(
        from opportunities: [Opportunity],
        activityKeys: Set<String>,
        holdingKeys: Set<String>,
        livePickKeys: Set<String>
    ) -> [Opportunity] {
        rankedUniverse(from: opportunities).filter { opportunity in
            let key = laneKey(opportunity)

            guard opportunity.orderState != .filled else { return false }
            guard !activityKeys.contains(key) else { return false }
            guard !holdingKeys.contains(key) else { return false }
            guard !livePickKeys.contains(key) else { return false }

            return true
        }
    }
}

extension WealthRootView {
    var rankedUniverseOpportunities: [Opportunity] {
        WealthOpportunityLaneRules.rankedUniverse(from: engine.rankedAssets)
    }

    var holdingLaneKeys: Set<String> {
        Set(
            portfolio.holdings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
    }

    var activityLaneKeys: Set<String> {
        Set(pendingOpportunities.map(WealthOpportunityLaneRules.laneKey))
    }

    var livePickLaneKeys: Set<String> {
        Set(livePickOpportunities.map(WealthOpportunityLaneRules.laneKey))
    }

    var marketRankedOpportunities: [Opportunity] {
        WealthOpportunityLaneRules.marketLane(
            from: rankedUniverseOpportunities,
            activityKeys: activityLaneKeys,
            holdingKeys: holdingLaneKeys,
            livePickKeys: livePickLaneKeys
        )
    }

    var confirmedHoldings: [Holding] {
        portfolio.holdings.filter {
            ($0.orderIntent == .live || $0.orderIntent == .sellPending) && $0.orderState != .filled
        }
    }

    var pendingHoldings: [Holding] {
        portfolio.holdings.filter { $0.orderIntent == .sellPending && $0.orderState != .filled }
    }

    var pendingOpportunities: [Opportunity] {
        portfolio.activityOpportunities.sorted(by: activityOpportunitySort)
    }

    var pendingBuyOpportunities: [Opportunity] {
        pendingOpportunities.filter {
            $0.orderState == .pending || $0.orderState == .submitted || $0.orderState == .partial
        }
    }

    var livePickOpportunities: [Opportunity] {
        WealthOpportunityLaneRules.livePicks(
            from: rankedUniverseOpportunities,
            activityKeys: activityLaneKeys,
            holdingKeys: holdingLaneKeys,
            spendableCash: portfolio.freeBuyingPower
        )
    }

    var completedOpportunities: [Opportunity] {
        portfolio.completedActivity.filter {
            $0.decisionBias == .avoid || $0.commandText == "SELL COMPLETED"
        }
    }

    var activityCount: Int {
        pendingHoldings.count + pendingOpportunities.count
    }

    var goalVector: WealthGoalVector {
        portfolio.goalVector()
    }

    var recentCompletedCount: Int {
        min(completedOpportunities.count, 3)
    }

    var activityBadgeCount: Int {
        activityCount + recentCompletedCount
    }

    var hasDesktopLayout: Bool {
#if targetEnvironment(macCatalyst) || os(macOS)
        true
#else
        false
#endif
    }
}
