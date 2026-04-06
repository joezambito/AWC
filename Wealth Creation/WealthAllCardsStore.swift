import Foundation
import Combine

@MainActor
final class WealthAllCardsStore: ObservableObject {
    nonisolated static let marketCardLimit = 100

    struct ColorDiagnosticsSummary: Equatable {
        let total: Int
        let green: Int
        let blue: Int
        let purple: Int
        let red: Int
        let grey: Int

        static let empty = ColorDiagnosticsSummary(total: 0, green: 0, blue: 0, purple: 0, red: 0, grey: 0)
    }

    static let shared = WealthAllCardsStore()

    @Published private(set) var reviewCards: [Opportunity] = []
    @Published private(set) var marketCards: [Opportunity] = []
    @Published private(set) var backgroundCards: [Opportunity] = []
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var colorDiagnosticsSummary: ColorDiagnosticsSummary = .empty

    private init() {}

    static func reviewCards(
        from opportunities: [Opportunity],
        activityKeys: Set<String>,
        holdingKeys: Set<String>,
        livePickKeys: Set<String>
    ) -> [Opportunity] {
        WealthOpportunityLaneRules.marketLane(
            from: opportunities,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: livePickKeys
        )
        .map(normalizePermissionForColorRule)
    }

    static func normalizePermissionForColorRule(_ opportunity: Opportunity) -> Opportunity {
        opportunity
    }

    static func visibleLivePickKeys(
        from opportunities: [Opportunity],
        aiLiveResults: [String: WealthAILiveResult],
        activityKeys: Set<String>,
        holdingKeys: Set<String>,
        spendableCash: Double
    ) -> Set<String> {
        let visibleReviewCards = reviewCards(
            from: opportunities,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: []
        )
        let visibleMarketCards = marketCards(from: visibleReviewCards)
        let livePicks = WealthOpportunityLaneRules.livePicks(
            from: visibleMarketCards,
            aiLiveResults: aiLiveResults,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            spendableCash: spendableCash
        )
        return Set(livePicks.map(WealthOpportunityLaneRules.laneKey))
    }

    static func marketCards(
        from reviewCards: [Opportunity],
        limit: Int = marketCardLimit
    ) -> [Opportunity] {
        let routed = WealthCardHoldingRouter.routeFromGreenCheckpoint(reviewCards)
        let executableGreenCards = routed.greenCards.filter(\.isMarketExecutableCandidate)
        let selected = WealthOpportunityLaneRules.marketTopCandidates(
            from: executableGreenCards,
            limit: min(limit, marketCardLimit)
        )
        return assignMarketRanks(to: selected)
    }

    static func backgroundCards(
        from opportunities: [Opportunity],
        marketCards: [Opportunity]
    ) -> [Opportunity] {
        let marketKeys = Set(marketCards.map(WealthOpportunityLaneRules.laneKey))
        return WealthOpportunityLaneRules.rankedUniverse(from: opportunities).filter {
            !marketKeys.contains(WealthOpportunityLaneRules.laneKey($0))
        }
    }

    func sync(
        opportunities: [Opportunity],
        activityKeys: Set<String>,
        holdingKeys: Set<String>,
        livePickKeys: Set<String>,
        refreshTime: Date?
    ) {
        applySync(
            opportunities: opportunities,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: livePickKeys,
            refreshTime: refreshTime,
            propagateToColorStores: true
        )
    }

    func syncVisibleCache(
        opportunities: [Opportunity],
        activityKeys: Set<String>,
        holdingKeys: Set<String>,
        livePickKeys: Set<String>,
        refreshTime: Date?
    ) {
        applySync(
            opportunities: opportunities,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: livePickKeys,
            refreshTime: refreshTime,
            propagateToColorStores: false
        )
    }

    private func applySync(
        opportunities: [Opportunity],
        activityKeys: Set<String>,
        holdingKeys: Set<String>,
        livePickKeys: Set<String>,
        refreshTime: Date?,
        propagateToColorStores: Bool
    ) {
        let fullRankedUniverse = WealthOpportunityLaneRules.rankedUniverse(from: opportunities)
        let nextReviewCards = Self.reviewCards(
            from: fullRankedUniverse,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: livePickKeys
        )

        let routed = WealthCardHoldingRouter.routeFromGreenCheckpoint(fullRankedUniverse)
        let greenCards = routed.greenCards
        let blueCards = routed.blueCards
        let purpleCards = routed.purpleCards
        let redCards = routed.redCards
        let greyCards = routed.greyCards

        let nextMarketCards = Self.marketCards(from: nextReviewCards)
        let marketStateValid = nextMarketCards.allSatisfy(\.isMarketExecutableCandidate)
        if !marketStateValid {
#if DEBUG
            assertionFailure("Non-executable card leaked into Market")
#endif
            WealthEventLogStore.shared.record(
                title: "Pipeline Rejected",
                detail: "Market contained a blocked or zero-share card after executable filtering.",
                category: "refresh",
                tintName: "red",
                timestamp: .now
            )
        }
        let nextBackgroundCards = Self.backgroundCards(from: fullRankedUniverse, marketCards: nextMarketCards)

        let diagnostics = ColorDiagnosticsSummary(
            total: fullRankedUniverse.count,
            green: greenCards.count,
            blue: blueCards.count,
            purple: purpleCards.count,
            red: redCards.count,
            grey: greyCards.count
        )

#if DEBUG
        if WealthPipelineTraceLogger.isEnabledForDebugOutput {
            NSLog(
                "[CardFlow] after_scoring totalCards=%ld green=%ld blue=%ld purple=%ld red=%ld grey=%ld regions=%@",
                fullRankedUniverse.count,
                greenCards.count,
                blueCards.count,
                purpleCards.count,
                redCards.count,
                greyCards.count,
                fullRankedUniverse.reduce(into: [String: Int]()) { partial, opportunity in
                    let region = WealthMarketLabels.region(for: opportunity.market)
                    partial[region, default: 0] += 1
                }
                .sorted { lhs, rhs in
                    if lhs.value != rhs.value { return lhs.value > rhs.value }
                    return lhs.key < rhs.key
                }
                .map { "\($0.key):\($0.value)" }
                .joined(separator: ",")
            )
            NSLog(
                "[CardFlow] stores green=%ld blue=%ld purple=%ld red=%ld grey=%ld",
                greenCards.count,
                blueCards.count,
                purpleCards.count,
                redCards.count,
                greyCards.count
            )
            NSLog(
                "[CardFlow] routing green->red=%ld green->grey=%ld green->allCards=%ld",
                0,
                0,
                nextBackgroundCards.count
            )
            NSLog(
                "[CardFlow] dispatcher blue=%ld purple=%ld",
                blueCards.count,
                purpleCards.count
            )
            NSLog(
                "[CardFlow] market input=%ld market=%ld",
                nextReviewCards.count,
                nextMarketCards.count
            )
        }
#endif

        WealthPipelineTraceLogger.log(stage: "all_cards_review_cache", opportunities: nextReviewCards)
        WealthPipelineTraceLogger.log(stage: "all_cards_market_cache", opportunities: nextMarketCards)

        if propagateToColorStores {
            WealthGreenCardsStore.shared.sync(cards: greenCards, refreshTime: refreshTime)
            WealthBlueCardsStore.shared.sync(cards: blueCards, refreshTime: refreshTime)
            WealthPurpleCardsStore.shared.sync(cards: purpleCards, refreshTime: refreshTime)
            WealthRedCardsStore.shared.sync(cards: redCards, refreshTime: refreshTime)
            WealthGreyCardsStore.shared.sync(cards: greyCards, refreshTime: refreshTime)
        }

        reviewCards = nextReviewCards
        marketCards = nextMarketCards
        backgroundCards = nextBackgroundCards
        colorDiagnosticsSummary = diagnostics
        lastRefresh = refreshTime
    }

    func cachedReviewCards(for refreshTime: Date?) -> [Opportunity]? {
        guard matches(refreshTime) else { return nil }
        return reviewCards
    }

    func currentReviewCards(preferredRefreshTime refreshTime: Date?) -> [Opportunity] {
        if let cached = cachedReviewCards(for: refreshTime), !cached.isEmpty {
            return cached
        }
        if !reviewCards.isEmpty {
            return reviewCards
        }
        guard shouldAllowStaleFallback(preferredRefreshTime: refreshTime) else { return [] }
        return reviewCards
    }

    func cachedMarketCards(for refreshTime: Date?) -> [Opportunity]? {
        guard matches(refreshTime) else { return nil }
        return marketCards
    }

    func currentMarketCards(preferredRefreshTime refreshTime: Date?) -> [Opportunity] {
        if let cached = cachedMarketCards(for: refreshTime), !cached.isEmpty {
            return cached
        }
        if !marketCards.isEmpty {
            return marketCards
        }
        guard shouldAllowStaleFallback(preferredRefreshTime: refreshTime) else { return [] }
        return marketCards
    }

    private func matches(_ refreshTime: Date?) -> Bool {
        guard let lastRefresh else { return refreshTime == nil }
        guard let refreshTime else { return false }
        return abs(lastRefresh.timeIntervalSince(refreshTime)) < 0.001
    }

    private func shouldAllowStaleFallback(preferredRefreshTime refreshTime: Date?) -> Bool {
        let engine = WealthEngineStore.shared
        if refreshTime == nil { return true }
        if engine.isDashboardRefreshInFlight || engine.isMarketMaterializationInFlight { return true }
        if engine.activationTask != nil || engine.pendingRefreshPayload != nil || engine.pendingPublishTask != nil {
            return true
        }
        return false
    }
}

private func assignMarketRanks(to opportunities: [Opportunity]) -> [Opportunity] {
    var currentTier: WealthMarketQualityTier?
    var tierPosition = 0

    return opportunities.map { opportunity in
        let tier = opportunity.marketQualityTier
        if tier != currentTier {
            currentTier = tier
            tierPosition = 1
        } else {
            tierPosition += 1
        }
        return opportunity.withRank(tierPosition)
    }
}

private func persistedMarketOrdering(lhs: Opportunity, rhs: Opportunity) -> Bool {
    let leftTier = lhs.marketQualityTier.rawValue
    let rightTier = rhs.marketQualityTier.rawValue
    if leftTier != rightTier { return leftTier < rightTier }

    if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
    return lhs.symbol.localizedStandardCompare(rhs.symbol) == .orderedAscending
}
