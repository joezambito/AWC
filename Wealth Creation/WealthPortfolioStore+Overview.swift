import Foundation

extension WealthPortfolioStore {
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

    var effectiveReservedCapital: Double { totalBuyReservedCapital }
    var availableToTrade: Double { max(0, brokerCashBalance - floorReserve - effectiveReservedCapital) }
    var availableCapital: Double { availableToTrade }
    var committedCapital: Double { currentlyInvested + pendingBuyReserveCapital }
    var totalAccountAmount: Double { availableToTrade + totalBuyReservedCapital + floorReserve + holdingsValue }
    var portfolioValue: Double { totalAccountAmount }
    var portfolioAmount: Double { totalAccountAmount }
    var tradingCapital: Double { availableCapital }
    var investedCapital: Double { committedCapital }
    var capitalBaseline: Double { max(protectedBaseCapital, externalDeposits) }
    var totalPnL: Double {
        deployedHoldings.reduce(0) { running, holding in
            if holding.orderIntent == .sellPending {
                return running + holding.pendingNetPnL
            }
            return running + holding.netPnL
        }
    }
    var profitOnlyProgress: Double { earnedProfit }
    var reusableBuyingPower: Double { availableCapital }
    var freeBuyingPower: Double { availableCapital }

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
        GoalProgress(target: target, actual: dailyGoalActual)
    }

    func compoundGoal(target: Double) -> GoalProgress {
        GoalProgress(target: target, actual: compoundGoalActual)
    }

    func missionGoal(target: Double) -> GoalProgress {
        GoalProgress(target: target, actual: missionGoalActual)
    }

    func goalVector() -> WealthGoalVector {
        let defaults = UserDefaults.standard
        let dailyTarget = defaults.object(forKey: "awc_daily_target") as? Double ?? 100
        let compoundTarget = defaults.object(forKey: "awc_campaign_target") as? Double ?? 1_000
        let missionTarget = defaults.object(forKey: "awc_mission_amount") as? Double ?? 25_000

        return WealthGoalVector(
            daily: dailyGoal(target: dailyTarget),
            compound: compoundGoal(target: compoundTarget),
            mission: missionGoal(target: missionTarget)
        )
    }

    func applySnapshot(from opportunities: [Opportunity]) {
        let lookup = Dictionary(
            uniqueKeysWithValues: opportunities.map {
                (overviewKey(symbol: $0.symbol, market: $0.market), $0)
            }
        )

        holdings = holdings.map { holding in
            let key = overviewKey(symbol: holding.symbol, market: holding.market)
            guard let live = lookup[key] else { return holding }

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
        holdings.filter { $0.orderIntent != .buyPending }
    }
}
