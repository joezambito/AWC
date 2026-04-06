import Foundation

extension WealthPortfolioStore {
    private var hasMeaningfulPortfolioState: Bool {
        !holdings.isEmpty ||
        !queuedOpportunities.isEmpty ||
        externalDeposits != 0 ||
        protectedBaseCapital != 0 ||
        earnedProfit != 0 ||
        dailyProfit != 0 ||
        reservedOrderCapital != 0
    }

    private var normalizedDisplayCashBalance: Double {
        let protection = WealthProtectionSettingsStore.shared
        if protection.demoMode {
            if !hasMeaningfulPortfolioState, protection.demoBalance > 0 {
                return 0
            }
            return protection.demoBalance
        }
        return WealthBrokerStore.shared.executionCashBalance
    }

    var hasPendingBrokerLifecycleWork: Bool {
        holdings.contains { $0.orderIntent == .buyPending || $0.orderIntent == .sellPending }
    }

    var brokerCashBalance: Double {
        let protection = WealthProtectionSettingsStore.shared
        if protection.demoMode {
            return protection.demoBalance
        }
        return WealthBrokerStore.shared.executionCashBalance
    }

    var floorReserve: Double { WealthProtectionSettingsStore.shared.floorReserve }

    var holdingsValue: Double {
        deployedHoldings.reduce(0) { running, holding in
            running + effectiveHoldingValue(for: holding)
        }
    }

    var currentlyInvested: Double {
        deployedHoldings.reduce(0) { $0 + $1.buyTotalCost }
    }

    var availableToTrade: Double {
        max(0, brokerCashBalance - floorReserve - effectiveReservedCapital)
    }

    var availableCapital: Double {
        availableToTrade
    }

    var committedCapital: Double {
        currentlyInvested + pendingBuyReserveCapital
    }

    var totalAccountAmount: Double {
        normalizedDisplayCashBalance + holdingsValue
    }

    var totalPnL: Double {
        deployedHoldings.reduce(0) { running, holding in
            if holding.orderIntent == .sellPending {
                return running + holding.pendingNetPnL
            }
            return running + holding.netPnL
        }
    }

    var profitOnlyProgress: Double {
        earnedProfit
    }

    var reusableBuyingPower: Double {
        availableCapital
    }

    var freeBuyingPower: Double {
        availableCapital
    }
    var effectiveReservedCapital: Double { totalBuyReservedCapital }
    var portfolioValue: Double { totalAccountAmount }
    var portfolioAmount: Double { totalAccountAmount }
    var tradingCapital: Double { availableCapital }
    var investedCapital: Double { committedCapital }
    var capitalBaseline: Double { max(protectedBaseCapital, externalDeposits) }

    var runtimeMoneySnapshot: WealthPortfolioRuntimeMoneySnapshot {
        let positions = holdings.filter { $0.orderIntent != .buyPending && $0.orderState != .filled }
        let buyReserved = totalBuyReservedCapital
        let cashBalance = normalizedDisplayCashBalance
        let holdingsValue = self.holdingsValue

        return WealthPortfolioRuntimeMoneySnapshot(
            cashBalance: cashBalance,
            availableCapital: max(0, cashBalance - floorReserve - buyReserved),
            committedCapital: currentlyInvested + pendingBuyReserveCapital,
            holdingsValue: holdingsValue,
            accountValue: cashBalance + holdingsValue,
            buyReserved: buyReserved,
            sellReturning: pendingSellReturnCapital,
            totalPnL: totalPnL,
            holdingsCount: holdings.count,
            positionsCount: positions.count
        )
    }

    var pendingBuyReserveCapital: Double {
        holdings
            .filter { $0.orderIntent == .buyPending }
            .reduce(0) { $0 + buyCost(for: $1.shares, price: $1.averagePrice) }
    }

    var queuedBuyReserveCapital: Double {
        queuedOpportunities.reduce(0) { $0 + $1.trueCost }
    }

    var pendingSellReturnCapital: Double {
        holdings
            .filter { $0.orderIntent == .sellPending }
            .reduce(0) { $0 + $1.pendingNetValue }
    }

    var totalBuyReservedCapital: Double { pendingBuyReserveCapital + queuedBuyReserveCapital }

    var activityOpportunities: [Opportunity] {
        let pendingBuys = holdings
            .filter { $0.orderIntent == .buyPending && $0.orderState != .filled }
            .map(pendingOpportunity(from:))
        let combined = queuedOpportunities + pendingBuys
        var seen: Set<String> = []
        return combined.filter {
            let key = overviewKey(symbol: $0.symbol, market: $0.market)
            return seen.insert(key).inserted
        }
    }

    func dailyGoal(target: Double) -> GoalProgress {
        GoalProgress(target: max(0, target), actual: dailyGoalActual)
    }

    func compoundGoal(target: Double) -> GoalProgress {
        GoalProgress(target: max(0, target), actual: compoundGoalActual)
    }

    func missionGoal(target: Double) -> GoalProgress {
        GoalProgress(target: max(0, target), actual: missionGoalActual)
    }

    func goalVector() -> WealthGoalVector {
        let defaults = UserDefaults.standard

        let dailyTarget = max(0, defaults.object(forKey: "awc_daily_target") as? Double ?? 100)
        let compoundTarget = max(0, defaults.object(forKey: "awc_campaign_target") as? Double ?? 1_000)
        let missionTarget = max(0, defaults.object(forKey: "awc_mission_amount") as? Double ?? 25_000)

        refreshGoalBaselinesIfNeeded(
            dailyTarget: dailyTarget,
            compoundTarget: compoundTarget,
            missionTarget: missionTarget
        )

        return WealthGoalVector(
            daily: dailyGoal(target: dailyTarget),
            compound: compoundGoal(target: compoundTarget),
            mission: missionGoal(target: missionTarget),
            compoundTimePressure: compoundRemainingWindowPressure(),
            missionTimePressure: missionRemainingWindowPressure()
        )
    }

    func applySnapshot(from opportunities: [Opportunity]) {
        let lookup = Dictionary(
            uniqueKeysWithValues: opportunities.map {
                (overviewKey(symbol: $0.symbol, market: $0.market), $0)
            }
        )

        holdings = holdings.compactMap { holding in
            let key = overviewKey(symbol: holding.symbol, market: holding.market)
            let keepPending = holding.orderIntent == .buyPending || holding.orderIntent == .sellPending
            guard let live = lookup[key] else {
                return keepPending ? holding : nil
            }

            var next = holding
            next.currentPrice = WealthHoldingLivePriceResolver.resolvedCurrentPrice(
                currentPrice: holding.currentPrice,
                livePrice: live.price,
                averagePrice: holding.averagePrice
            )
            next.aiScore = live.aiScore
            next.aiBand = live.rank
            next.confidence = live.confidence
            next.safety = live.safety
            next.prospect = live.prospect
            next.timeWindow = live.timeWindow
            next.riskLabel = live.aiRiskStance
            next.sourceTrigger = live.sourceTrigger
            next.dataOrigin = live.dataOrigin
            next.reviewSummary = live.reviewSummary
            next.researchSummary = live.sourceSummary
            next.analysisTimestamp = live.analysisTimestamp
            next.dataTimestamp = live.dataTimestamp
            next.lastRefreshTimestamp = live.lastRefreshTimestamp
            if next.orderIntent == .buyPending, next.orderState == .ready {
                next.orderState = live.orderState
            }
            return next
        }

        lastRefresh = .now
    }

    func addDemoCredits(_ amount: Double) {
        let credit = max(0, amount)
        guard credit > 0 else { return }

        let protection = WealthProtectionSettingsStore.shared
        protection.demoBalance += credit
        protection.demoMode = true
        externalDeposits += credit
        protectedBaseCapital = max(protectedBaseCapital, externalDeposits)
        lastRefresh = .now
    }

    func normalizeRuntimeBalancesIfNeeded() {
        let protection = WealthProtectionSettingsStore.shared
        guard protection.demoMode else { return }
        guard protection.demoBalance > 0 else { return }
        guard !hasMeaningfulPortfolioState else { return }

        protection.demoBalance = 0
        protection.demoMode = false
        lastRefresh = .now
    }

    private func overviewKey(symbol: String, market: String) -> String {
        "\(symbol.uppercased())-\(market.uppercased())"
    }

    private func effectiveHoldingValue(for holding: Holding) -> Double {
        if holding.orderIntent == .sellPending {
            return holding.pendingNetValue
        }
        return holding.netLiquidationValue
    }

    private var deployedHoldings: [Holding] {
        holdings.filter { $0.orderState == .filled }
    }
}
