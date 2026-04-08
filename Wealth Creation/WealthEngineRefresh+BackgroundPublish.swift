import Foundation
import SwiftUI

extension WealthEngineStore {
    func persistBackgroundRefreshCache(_ payload: PendingRefreshPayload) {
        let portfolio = WealthPortfolioStore.shared
        let activityKeys = Set(portfolio.activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
        let holdingKeys = Set(
            portfolio.holdings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
        let reviewCards = WealthAllCardsStore.reviewCards(
            from: payload.opportunities,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: []
        )
        let marketCards = WealthAllCardsStore.marketCards(from: reviewCards)
        let aiLiveCandidates = WealthOpportunityLaneRules.aiLiveMarketRequestSet(
            from: marketCards,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            limit: WealthAllCardsStore.marketCardLimit
        )
        let aiLiveEvaluation = WealthAILiveCoordinator.evaluate(
            opportunities: aiLiveCandidates,
            currentActivity: portfolio.activityOpportunities,
            holdings: portfolio.holdings,
            spendableCash: portfolio.freeBuyingPower + portfolio.activityOpportunities.reduce(0) { $0 + $1.trueCost },
            returnedFromActivity: activityRefusalsByKey
        )

        let nextLastHeavyRefresh: Date?
        if payload.mode == .heavy || payload.mode == .deep {
            nextLastHeavyRefresh = payload.refreshTime
        } else {
            nextLastHeavyRefresh = lastHeavyRefresh
        }

        persistMarketCacheSnapshot(
            rankedAssets: payload.opportunities,
            scanUniverse: payload.opportunities,
            aiLiveResultsByKey: aiLiveEvaluation.resultsByKey,
            lastRefresh: payload.refreshTime,
            lastHeavyRefresh: nextLastHeavyRefresh
        )
    }

    func applyEmptyRefreshState(
        mode: RefreshMode,
        refreshTime: Date,
        countsTowardDailyCycles: Bool,
        publishToUI: Bool
    ) {
        updateRecurringCycleState(
            mode: mode,
            refreshTime: refreshTime,
            countsTowardDailyCycles: countsTowardDailyCycles
        )

        if publishToUI {
            let hasVisibleCache =
                !scanUniverse.isEmpty ||
                !rankedAssets.isEmpty ||
                !WealthAllCardsStore.shared.reviewCards.isEmpty ||
                !WealthAllCardsStore.shared.marketCards.isEmpty

            if hasVisibleCache {
                isUsingCachedMarketData = true
                lastDecisionSummary = "WAITING FOR MARKET OPEN"
                if activationTask == nil {
                    activationStage = 0
                    activationCycleComplete = true
                    lockedCheckpointProgress = Self.lockedCheckpointCount
                }

                let money = WealthPortfolioStore.shared.runtimeMoneySnapshot
                stagedDashboardSnapshot = DashboardSnapshot(
                    cashBalance: money.cashBalance,
                    availableCapital: money.availableCapital,
                    committedCapital: money.committedCapital,
                    holdingsValue: money.holdingsValue,
                    accountValue: money.accountValue,
                    buyReserved: money.buyReserved,
                    sellReturning: money.sellReturning,
                    totalPnL: money.totalPnL
                )
                WealthMoneyTraceLogger.log(
                    stage: "dashboard_empty_preserved",
                    snapshot: money,
                    marketCandidates: WealthAllCardsStore.shared.marketCards.count
                )
                scanProgressAnimationTask?.cancel()
                scanProgressAnimationTask = nil
                scanProgressAnimationEndsAt = nil

                if isDashboardRefreshInFlight {
                    withAnimation(.none) {
                        dashboardSnapshot = stagedDashboardSnapshot ?? dashboardSnapshot
                    }
                    endDashboardRefreshFreeze()
                }
                return
            }

            scanUniverse = []
            rankedAssets = []
            lastRefresh = refreshTime
            isUsingCachedMarketData = false
            WealthPortfolioStore.shared.normalizeRuntimeBalancesIfNeeded()
            WealthDataAliveStore.shared.sync(cards: [], refreshTime: refreshTime)
            WealthAIScoreStore.shared.sync(cards: [], refreshTime: refreshTime)
            WealthConfidenceStore.shared.sync(cards: [], refreshTime: refreshTime)
            WealthAllCardsStore.shared.sync(
                opportunities: [],
                activityKeys: [],
                holdingKeys: [],
                livePickKeys: [],
                refreshTime: refreshTime
            )
            if mode == .deep {
                let colorSummary = WealthAllCardsStore.shared.colorDiagnosticsSummary
                NSLog(
                    "Market color counts -> total: %ld, green: %ld, blue: %ld, purple: %ld, red: %ld, grey: %ld",
                    colorSummary.total,
                    colorSummary.green,
                    colorSummary.blue,
                    colorSummary.purple,
                    colorSummary.red,
                    colorSummary.grey
                )
            }

            if mode == .heavy || mode == .deep {
                lastHeavyRefresh = refreshTime
            }

            lastDecisionSummary = "WAITING FOR MARKET OPEN"
            if activationTask == nil {
                activationStage = 0
                activationCycleComplete = true
                lockedCheckpointProgress = Self.lockedCheckpointCount
            }
            WealthBrainStore.shared.ingest(
                opportunities: [],
                focusOpportunity: nil,
                stage: activationStage,
                stageTotal: activationStageTotal,
                cycleComplete: activationCycleComplete,
                lastRefresh: lastRefresh
            )

            let money = WealthPortfolioStore.shared.runtimeMoneySnapshot
            stagedDashboardSnapshot = DashboardSnapshot(
                cashBalance: money.cashBalance,
                availableCapital: money.availableCapital,
                committedCapital: money.committedCapital,
                holdingsValue: money.holdingsValue,
                accountValue: money.accountValue,
                buyReserved: money.buyReserved,
                sellReturning: money.sellReturning,
                totalPnL: money.totalPnL
            )
            WealthMoneyTraceLogger.log(
                stage: "dashboard_empty_publish",
                snapshot: money,
                marketCandidates: 0
            )
            scanProgressAnimationTask?.cancel()
            scanProgressAnimationTask = nil
            scanProgressAnimationEndsAt = nil

            if isDashboardRefreshInFlight {
                withAnimation(.none) {
                    dashboardSnapshot = stagedDashboardSnapshot ?? dashboardSnapshot
                }
                endDashboardRefreshFreeze()
            }
        } else {
            return
        }
    }
}
