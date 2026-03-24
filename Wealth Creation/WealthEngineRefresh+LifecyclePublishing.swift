import Foundation

extension WealthEngineStore {
    func applyResolvedRefresh(_ payload: PendingRefreshPayload) {
        let protection = WealthProtectionSettingsStore.shared
        let portfolio = WealthPortfolioStore.shared
        let isDeepRefresh = payload.mode == .deep
        let openingCycleRefresh = activationTask != nil || (!tradingLifecycleArmed && !activationCycleComplete)

        let finalRankedAssets = portfolio.reconcileEngineState(
            opportunities: payload.opportunities,
            mode: payload.mode,
            protection: protection,
            allowNewOrders: tradingLifecycleArmed || isDeepRefresh
        )

        rankedAssets = finalRankedAssets
        scannedSignals = payload.scannedSignals
        lastRefresh = payload.refreshTime
        brainSnapshot = Self.makeBrainSnapshot(
            goals: payload.goals,
            regime: payload.regime,
            mode: payload.brainMode,
            hunger: payload.hungerMode,
            hottest: finalRankedAssets.first
        )

        if payload.mode == .heavy || isDeepRefresh {
            lastHeavyRefresh = payload.refreshTime
        }

        portfolio.setReservedOrderCapital(
            portfolio.pendingBuyReserveCapital + portfolio.queuedBuyReserveCapital
        )
        portfolio.applySnapshot(from: finalRankedAssets)
        dashboardSnapshot = DashboardSnapshot(
            cashBalance: portfolio.brokerCashBalance,
            availableCapital: portfolio.availableCapital,
            committedCapital: portfolio.committedCapital,
            holdingsValue: portfolio.holdingsValue,
            accountValue: portfolio.totalAccountAmount,
            buyReserved: portfolio.totalBuyReservedCapital,
            sellReturning: portfolio.pendingSellReturnCapital,
            totalPnL: portfolio.totalPnL
        )

        lastDecisionSummary = finalRankedAssets.first.map {
            "\($0.commandText) · \($0.allocationPercent)% size · \($0.targetPressureLabel)"
        } ?? "Monitoring"

        WealthBrainStore.shared.ingest(
            opportunities: finalRankedAssets,
            stage: activationStage,
            stageTotal: activationStageTotal,
            cycleComplete: isDeepRefresh,
            lastRefresh: lastRefresh
        )

        if isDeepRefresh {
            WealthNotificationStore.shared.processEngineMoments(
                opportunities: finalRankedAssets,
                holdings: portfolio.holdings,
                buyingPower: payload.buyingPower,
                protection: protection
            )

            tradingLifecycleArmed = true
            activationCycleComplete = true
            activationStage = 0
        } else if !openingCycleRefresh {
            activationStage = 0
            activationCycleComplete = true
        }
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
            rankedAssets = []
            scannedSignals = []
            lastRefresh = refreshTime

            if mode == .heavy || mode == .deep {
                lastHeavyRefresh = refreshTime
            }

            lastDecisionSummary = "WAITING FOR MARKET OPEN"
            if activationTask == nil {
                activationStage = 0
                activationCycleComplete = true
            }
            WealthBrainStore.shared.ingest(
                opportunities: [],
                stage: activationStage,
                stageTotal: activationStageTotal,
                cycleComplete: activationCycleComplete,
                lastRefresh: lastRefresh
            )
        } else {
            pendingPublishTask?.cancel()
            pendingPublishTask = nil
            pendingRefreshPayload = nil
            lastDecisionSummary = "AI scan \(activationStage)/\(activationStageTotal) running. Results stay frozen until the cycle finishes."
        }
    }
}
