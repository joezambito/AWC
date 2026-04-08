import Foundation
import SwiftUI

extension WealthEngineStore {
    private var startupMaterializationGapNanoseconds: UInt64 { 120_000_000 }

    private struct ResolvedRefreshState {
        let finalRankedAssets: [Opportunity]
        let reviewCards: [Opportunity]
        let publishedCards: [Opportunity]
        let activityKeys: Set<String>
        let holdingKeys: Set<String>
        let livePickKeys: Set<String>
        let brainFocusOpportunity: Opportunity?
        let isDeepRefresh: Bool
        let openingCycleRefresh: Bool
    }

    private var stagedCardPublishGapNanoseconds: UInt64 {
#if targetEnvironment(macCatalyst)
        prefersFullSpeedActivation ? 0 : 350_000_000
#else
        0
#endif
    }

    private func resolvedRefreshState(for payload: PendingRefreshPayload) -> ResolvedRefreshState {
        let protection = WealthProtectionSettingsStore.shared
        let portfolio = WealthPortfolioStore.shared
        let isDeepRefresh = payload.mode == .deep
        let openingCycleRefresh = activationTask != nil || (!tradingLifecycleArmed && !activationCycleComplete)

        portfolio.normalizeRuntimeBalancesIfNeeded()

        let finalRankedAssets = portfolio.reconcileEngineState(
            opportunities: payload.opportunities,
            mode: payload.mode,
            protection: protection,
            allowNewOrders: (tradingLifecycleArmed || isDeepRefresh) && activityPromotionGateSatisfied
        )
        let activityKeys = Set(portfolio.activityOpportunities.map(WealthOpportunityLaneRules.laneKey))
        let holdingKeys = Set(
            portfolio.holdings
                .filter { $0.orderState != .filled }
                .map(WealthOpportunityLaneRules.laneKey)
        )
        let livePickKeys = WealthAllCardsStore.visibleLivePickKeys(
            from: finalRankedAssets,
            aiLiveResults: aiLiveResultsByKey,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            spendableCash: portfolio.freeBuyingPower
        )
        let reviewCards = WealthAllCardsStore.reviewCards(
            from: finalRankedAssets,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: livePickKeys
        )
        let publishedCards = WealthAllCardsStore.marketCards(from: reviewCards)
        let brainFocusOpportunity = WealthOpportunityLaneRules.brainFocusOpportunity(
            from: publishedCards.isEmpty ? finalRankedAssets : publishedCards
        )

        return ResolvedRefreshState(
            finalRankedAssets: finalRankedAssets,
            reviewCards: reviewCards,
            publishedCards: publishedCards,
            activityKeys: activityKeys,
            holdingKeys: holdingKeys,
            livePickKeys: livePickKeys,
            brainFocusOpportunity: brainFocusOpportunity,
            isDeepRefresh: isDeepRefresh,
            openingCycleRefresh: openingCycleRefresh
        )
    }

    private func validatedPipelineState(_ state: ResolvedRefreshState) -> ResolvedRefreshState? {
        let expectedReview = WealthAllCardsStore.reviewCards(
            from: state.finalRankedAssets,
            activityKeys: state.activityKeys,
            holdingKeys: state.holdingKeys,
            livePickKeys: state.livePickKeys
        )
        let expectedMarket = WealthAllCardsStore.marketCards(from: expectedReview)

        let matchesReview =
            expectedReview.map(WealthOpportunityLaneRules.laneKey) ==
            state.reviewCards.map(WealthOpportunityLaneRules.laneKey)
        let matchesMarket =
            expectedMarket.map(WealthOpportunityLaneRules.laneKey) ==
            state.publishedCards.map(WealthOpportunityLaneRules.laneKey)

        guard matchesReview, matchesMarket else {
#if DEBUG
            assertionFailure("Rejected cross-stage Market pipeline sync")
#endif
            WealthEventLogStore.shared.record(
                title: "Pipeline Rejected",
                detail: "Publish path rejected a cross-stage Market sync attempt.",
                category: "refresh",
                tintName: "red",
                timestamp: .now
            )
            return nil
        }

        return state
    }

    private func applyResolvedRefreshPhaseOne(
        _ state: ResolvedRefreshState,
        payload: PendingRefreshPayload
    ) {
        let existingVisibleCount = max(scanUniverse.count, rankedAssets.count)
        let preserveVisibleOpeningCards =
            state.openingCycleRefresh &&
            startupSequencePhase == .aiScanRunning &&
            existingVisibleCount > state.finalRankedAssets.count &&
            existingVisibleCount > 0

        if !preserveVisibleOpeningCards {
            scanUniverse = state.finalRankedAssets
            rankedAssets = state.finalRankedAssets
        }
        scannedSignals = payload.scannedSignals
        lastRefresh = payload.refreshTime
        isUsingCachedMarketData = false
        brainSnapshot = Self.makeBrainSnapshot(
            goals: payload.goals,
            regime: payload.regime,
            mode: payload.brainMode,
            hunger: payload.hungerMode,
            hottest: state.brainFocusOpportunity
        )

        if payload.mode == .heavy || state.isDeepRefresh {
            lastHeavyRefresh = payload.refreshTime
        }

        lastDecisionSummary = state.publishedCards.first.map {
            "\($0.commandText) · \($0.allocationPercent)% size · \($0.targetPressureLabel)"
        } ?? "Monitoring"
    }

    private func finalizeResolvedRefreshPhaseTwo(
        _ state: ResolvedRefreshState,
        payload: PendingRefreshPayload
    ) {
        let protection = WealthProtectionSettingsStore.shared
        let portfolio = WealthPortfolioStore.shared

        if state.isDeepRefresh {
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
        let money = portfolio.runtimeMoneySnapshot
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
            stage: "dashboard_publish",
            snapshot: money,
            marketCandidates: WealthAllCardsStore.shared.marketCards.count
        )

        WealthBrainStore.shared.ingest(
            opportunities: state.publishedCards,
            focusOpportunity: state.brainFocusOpportunity,
            stage: activationStage,
            stageTotal: activationStageTotal,
            cycleComplete: state.isDeepRefresh,
            lastRefresh: lastRefresh
        )

        if activationTask == nil {
            if state.isDeepRefresh && !state.openingCycleRefresh {
                WealthNotificationStore.shared.processEngineMoments(
                    opportunities: state.publishedCards,
                    holdings: portfolio.holdings,
                    buyingPower: payload.buyingPower,
                    protection: protection
                )

                tradingLifecycleArmed = true
                activationCycleComplete = true
                activationStage = 0
                lockedCheckpointProgress = Self.lockedCheckpointCount
            } else if !state.openingCycleRefresh {
                activationStage = 0
                activationCycleComplete = true
                lockedCheckpointProgress = Self.lockedCheckpointCount
            }
        }

        persistMarketCache()
    }

    private func applyResolvedRefreshPhaseTwo(
        _ state: ResolvedRefreshState,
        payload: PendingRefreshPayload,
        transaction: Transaction
    ) async {
        let portfolio = WealthPortfolioStore.shared
        let stageGap = activationTask != nil ? startupMaterializationGapNanoseconds : 0

        withTransaction(transaction) {
            portfolio.setReservedOrderCapital(
                portfolio.pendingBuyReserveCapital + portfolio.queuedBuyReserveCapital
            )
            portfolio.applySnapshot(from: state.finalRankedAssets)
        }

        if stageGap > 0 {
            try? await Task.sleep(nanoseconds: stageGap)
        } else {
            await Task.yield()
        }

        withTransaction(transaction) {
            WealthDataAliveStore.shared.sync(cards: state.finalRankedAssets, refreshTime: payload.refreshTime)
        }

        if stageGap > 0 {
            try? await Task.sleep(nanoseconds: stageGap)
        } else {
            await Task.yield()
        }

        withTransaction(transaction) {
            WealthAIScoreStore.shared.sync(cards: state.finalRankedAssets, refreshTime: payload.refreshTime)
        }

        if stageGap > 0 {
            try? await Task.sleep(nanoseconds: stageGap)
        } else {
            await Task.yield()
        }

        withTransaction(transaction) {
            WealthConfidenceStore.shared.sync(cards: state.finalRankedAssets, refreshTime: payload.refreshTime)
        }

        if stageGap > 0 {
            try? await Task.sleep(nanoseconds: stageGap)
        } else {
            await Task.yield()
        }

        let preserveVisibleMarketCache =
            state.openingCycleRefresh &&
            startupSequencePhase == .aiScanRunning &&
            !WealthAllCardsStore.shared.marketCards.isEmpty

        withTransaction(transaction) {
            if !preserveVisibleMarketCache {
                WealthAllCardsStore.shared.sync(
                    opportunities: state.finalRankedAssets,
                    activityKeys: state.activityKeys,
                    holdingKeys: state.holdingKeys,
                    livePickKeys: state.livePickKeys,
                    refreshTime: payload.refreshTime
                )
            }
        }

        if stageGap > 0 {
            try? await Task.sleep(nanoseconds: stageGap)
        } else {
            await Task.yield()
        }

        withTransaction(transaction) {
            finalizeResolvedRefreshPhaseTwo(state, payload: payload)
        }
    }

    func applyResolvedRefreshSequence(_ payload: PendingRefreshPayload) async {
        guard let state = validatedPipelineState(resolvedRefreshState(for: payload)) else { return }
        var noAnimationTransaction = Transaction(animation: nil)
        noAnimationTransaction.disablesAnimations = true

        withTransaction(noAnimationTransaction) {
            applyResolvedRefreshPhaseOne(state, payload: payload)
        }

        if stagedCardPublishGapNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: stagedCardPublishGapNanoseconds)
        }

        await applyResolvedRefreshPhaseTwo(
            state,
            payload: payload,
            transaction: noAnimationTransaction
        )
    }

    func applyResolvedRefresh(_ payload: PendingRefreshPayload) {
        guard let state = validatedPipelineState(resolvedRefreshState(for: payload)) else { return }
        var noAnimationTransaction = Transaction(animation: nil)
        noAnimationTransaction.disablesAnimations = true

        withTransaction(noAnimationTransaction) {
            applyResolvedRefreshPhaseOne(state, payload: payload)
        }

        withTransaction(noAnimationTransaction) {
            WealthPortfolioStore.shared.setReservedOrderCapital(
                WealthPortfolioStore.shared.pendingBuyReserveCapital +
                WealthPortfolioStore.shared.queuedBuyReserveCapital
            )
            WealthPortfolioStore.shared.applySnapshot(from: state.finalRankedAssets)
        }

        withTransaction(noAnimationTransaction) {
            WealthDataAliveStore.shared.sync(cards: state.finalRankedAssets, refreshTime: payload.refreshTime)
        }

        withTransaction(noAnimationTransaction) {
            WealthAIScoreStore.shared.sync(cards: state.finalRankedAssets, refreshTime: payload.refreshTime)
        }

        withTransaction(noAnimationTransaction) {
            WealthConfidenceStore.shared.sync(cards: state.finalRankedAssets, refreshTime: payload.refreshTime)
        }

        withTransaction(noAnimationTransaction) {
            WealthAllCardsStore.shared.sync(
                opportunities: state.finalRankedAssets,
                activityKeys: state.activityKeys,
                holdingKeys: state.holdingKeys,
                livePickKeys: state.livePickKeys,
                refreshTime: payload.refreshTime
            )
        }

        withTransaction(noAnimationTransaction) {
            finalizeResolvedRefreshPhaseTwo(state, payload: payload)
        }
    }
}
