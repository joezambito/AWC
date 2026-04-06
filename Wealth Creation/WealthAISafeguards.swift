import Foundation

enum WealthAISafeguards {
    static func dailyLossLocked(portfolio: WealthPortfolioStore) -> Bool {
        let threshold = max(120, portfolio.totalAccountAmount * 0.04)
        return portfolio.totalPnL <= -threshold
    }

    static func positionLimit(for mode: WealthAggressionMode) -> Int {
        switch mode {
        case .protect:
            return 5
        case .moderate:
            return 8
        case .aggressive:
            return 12
        }
    }

    static func sectorLimit(for mode: WealthAggressionMode) -> Int {
        switch mode {
        case .protect:
            return 1
        case .moderate:
            return 2
        case .aggressive:
            return 3
        }
    }

    static func rewardRiskRatio(expectedNetProfit: Double, totalCost: Double, risk: Double) -> Double {
        let riskBudget = max(1, totalCost * max(0.012, risk / 140.0))
        return expectedNetProfit / riskBudget
    }

    static func marketWideCircuitBreaker(for blueprints: [OpportunityBlueprint], regime: WealthMarketRegime) -> Bool {
        guard !blueprints.isEmpty else { return false }
        let stressed = blueprints.filter {
            $0.dataQualityLabel.uppercased() != "FRESH" ||
            $0.earningsEventRisk >= 55 ||
            $0.macroEventRisk >= 60 ||
            $0.slippageRisk >= 50 ||
            $0.risk >= 52
        }.count
        let stressRatio = Double(stressed) / Double(blueprints.count)
        if stressRatio >= 0.58 {
            return true
        }
        return regime == .defensive && stressRatio >= 0.42
    }

    static func volatilityShockState(priceChangePercent: Double, timeWindow: String) -> WealthPermissionState? {
        let absoluteMove = abs(priceChangePercent)
        if absoluteMove >= 12 {
            return .wait
        }
        if timeWindow == "HOURS" && absoluteMove >= 7 {
            return .wait
        }
        if timeWindow == "DAYS" && absoluteMove >= 9 {
            return .wait
        }
        return nil
    }

    static func spreadSpikeState(spreadBps: Double, slippageRisk: Double) -> WealthPermissionState? {
        if spreadBps >= 45 || slippageRisk >= 65 {
            return .wait
        }
        if spreadBps >= 28 || slippageRisk >= 45 {
            return .wait
        }
        return nil
    }

    static func shouldForceProtectiveSell(live: Opportunity, holding: Holding) -> Bool {
        if live.cardHoldingBucket == .red &&
            (live.trustState == .weak || !live.warningReason.isEmpty) {
            return true
        }
        if live.permission == .blocked &&
            live.trustState == .weak &&
            (live.dataQualityLabel.uppercased() != "FRESH" || !live.warningReason.isEmpty) {
            return true
        }
        if live.dataQualityLabel.uppercased() == "STALE" &&
            (live.trustState == .weak || live.cardHoldingBucket == .red) {
            return true
        }
        if holding.netReturnPercent < 0 && live.decisionBias == .avoid {
            return true
        }
        return false
    }
}
