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
            let leftHasRank = lhs.rank > 0
            let rightHasRank = rhs.rank > 0

            if leftHasRank != rightHasRank {
                return leftHasRank && !rightHasRank
            }

            if leftHasRank && rightHasRank {
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.symbol.localizedStandardCompare(rhs.symbol) == .orderedAscending
            }

            if lhs.aiScore != rhs.aiScore { return lhs.aiScore < rhs.aiScore }
            if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
            return lhs.symbol.localizedStandardCompare(rhs.symbol) == .orderedAscending
        }
    }

    static func livePicks(
        from opportunities: [Opportunity],
        aiLiveResults: [String: WealthAILiveResult],
        activityKeys: Set<String>,
        holdingKeys: Set<String>,
        spendableCash: Double
    ) -> [Opportunity] {
        _ = spendableCash
        guard WealthEngineStore.shared.aiLivePromotionGateSatisfied else { return [] }
        var selected: [Opportunity] = []
        let marketCandidates = aiLiveMarketRequestSet(
            from: opportunities,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            limit: WealthAllCardsStore.marketCardLimit
        )

        for opportunity in marketCandidates {
            let key = laneKey(opportunity)
            guard let aiLiveResult = aiLiveResults[key] else { continue }
            guard aiLiveResult.allowsActivityPromotion else { continue }

            selected.append(opportunity)
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

            guard isStructurallyValidForMarket(opportunity) else { return false }
            guard opportunity.orderState != .filled else { return false }
            guard !activityKeys.contains(key) else { return false }
            guard !holdingKeys.contains(key) else { return false }
            guard !livePickKeys.contains(key) else { return false }

            return true
        }
    }

    static func marketTopCandidates(
        from reviewCandidates: [Opportunity],
        limit: Int = WealthAllCardsStore.marketCardLimit
    ) -> [Opportunity] {
        var selected: [Opportunity] = []
        var seenKeys: Set<String> = []

        for opportunity in reviewCandidates.sorted(by: WealthEngineRefreshRanking.marketRankingOrder) {
            guard selected.count < limit else { break }
            guard opportunity.cardHoldingBucket == .green else { continue }
            guard isStructurallyValidForMarket(opportunity) else { continue }
            guard opportunity.orderState != .filled else { continue }
            let key = laneKey(opportunity)
            guard seenKeys.insert(key).inserted else { continue }
            selected.append(opportunity)
        }

        return selected
    }

    static func backgroundPool(
        from reviewCandidates: [Opportunity],
        activeMarketKeys: Set<String>
    ) -> [Opportunity] {
        reviewCandidates.filter { !activeMarketKeys.contains(laneKey($0)) }
    }

    static func aiLiveMarketRequestSet(
        from opportunities: [Opportunity],
        activityKeys: Set<String>,
        holdingKeys: Set<String>,
        limit: Int = WealthAllCardsStore.marketCardLimit
    ) -> [Opportunity] {
        let eligible = opportunities
            .sorted(by: marketPipelineOrder)
            .filter(isEligibleForAILiveReview)

        guard let highestTier = eligible.map(\.marketQualityTier).min(by: { $0.rawValue < $1.rawValue }) else {
            return []
        }

        var selected: [Opportunity] = []
        var seenKeys: Set<String> = []

        for opportunity in eligible where opportunity.marketQualityTier == highestTier {
            guard selected.count < limit else { break }
            let key = laneKey(opportunity)

            guard seenKeys.insert(key).inserted else { continue }
            guard !activityKeys.contains(key) else { continue }
            guard !holdingKeys.contains(key) else { continue }
            selected.append(opportunity)
        }

        return selected
    }

    static func brainFocusOpportunity(
        from opportunities: [Opportunity]
    ) -> Opportunity? {
        opportunities.first {
            !WealthMarketInstrumentCatalog.isReferenceInstrument(
                symbol: $0.symbol,
                market: $0.market
            )
        } ?? opportunities.first
    }

    nonisolated private static func isStructurallyValidForMarket(_ opportunity: Opportunity) -> Bool {
        let symbol = opportunity.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let market = opportunity.market.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !symbol.isEmpty else { return false }
        guard !market.isEmpty else { return false }
        guard opportunity.price.isFinite else { return false }
        guard opportunity.brokerFee.isFinite else { return false }
        guard opportunity.expectedProfit.isFinite else { return false }
        guard opportunity.priceChangePercent.isFinite else { return false }

        return true
    }

    // Universe Update 8/4/2026: The 5-minute refresh-age gate has been removed.
    // A ranked card stays eligible for AI Live indefinitely until it is bought
    // (orderState == .filled) or explicitly rejected (permission == .blocked).
    // Background refresh monitors the state; no time-based eviction occurs.
    nonisolated private static func isEligibleForAILiveReview(_ opportunity: Opportunity) -> Bool {
        guard isStructurallyValidForMarket(opportunity) else { return false }
        guard opportunity.orderState != .filled else { return false }
        guard opportunity.rank > 0 else { return false }
        guard opportunity.permission != .blocked else { return false }
        return true
    }

    nonisolated private static func marketPipelineOrder(_ lhs: Opportunity, _ rhs: Opportunity) -> Bool {
        let leftTier = WealthEngineRefreshRanking.marketQualityTier(for: lhs).rawValue
        let rightTier = WealthEngineRefreshRanking.marketQualityTier(for: rhs).rawValue
        if leftTier != rightTier {
            return leftTier < rightTier
        }

        let leftRank = lhs.rank > 0 ? lhs.rank : Int.max
        let rightRank = rhs.rank > 0 ? rhs.rank : Int.max
        if leftRank != rightRank {
            return leftRank < rightRank
        }

        return WealthEngineRefreshRanking.marketRankingOrder(lhs, rhs)
    }
}

extension WealthRootView {
    private var phoneVisibleActivityLimit: Int {
        hasDesktopLayout ? .max : 40
    }

    private var phoneVisibleCompletedLimit: Int {
        hasDesktopLayout ? .max : 12
    }

    private var phoneVisibleLivePickLimit: Int {
        hasDesktopLayout ? .max : 60
    }

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
        WealthAllCardsStore.shared.currentMarketCards(preferredRefreshTime: engine.lastRefresh)
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
        Array(portfolio.activityOpportunities.sorted(by: activityOpportunitySort).prefix(phoneVisibleActivityLimit))
    }

    var pendingBuyOpportunities: [Opportunity] {
        pendingOpportunities.filter {
            $0.orderState == .pending || $0.orderState == .submitted || $0.orderState == .partial
        }
    }

    var livePickOpportunities: [Opportunity] {
        Array(
            WealthOpportunityLaneRules.livePicks(
                from: marketRankedOpportunities,
                aiLiveResults: engine.aiLiveResultsByKey,
                activityKeys: activityLaneKeys,
                holdingKeys: holdingLaneKeys,
                spendableCash: portfolio.freeBuyingPower
            )
            .prefix(phoneVisibleLivePickLimit)
        )
    }

    var completedOpportunities: [Opportunity] {
        Array(
            portfolio.completedActivity.filter {
                $0.decisionBias == .avoid || $0.commandText == "SELL COMPLETED"
            }
            .prefix(phoneVisibleCompletedLimit)
        )
    }

    var activityCount: Int {
        pendingHoldingCount + pendingOpportunityCount
    }

    var goalVector: WealthGoalVector {
        portfolio.goalVector()
    }

    var recentCompletedCount: Int {
        min(completedOpportunityCount, 3)
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

    private var pendingHoldingCount: Int {
        portfolio.holdings.reduce(into: 0) { count, holding in
            guard holding.orderIntent == .sellPending else { return }
            guard holding.orderState != .filled else { return }
            count += 1
        }
    }

    private var pendingOpportunityCount: Int {
        portfolio.activityOpportunities.count
    }

    private var completedOpportunityCount: Int {
        portfolio.completedActivity.reduce(into: 0) { count, opportunity in
            guard opportunity.decisionBias == .avoid || opportunity.commandText == "SELL COMPLETED" else { return }
            count += 1
        }
    }
}
