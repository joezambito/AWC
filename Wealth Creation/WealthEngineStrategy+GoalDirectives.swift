import SwiftUI

extension WealthEngineStore {
    static func targetCoveragePercent(goals: WealthGoalVector, expectedNetProfit: Double) -> Int {
        let dominant = goals.dominantTarget
        let progress = goals.progress(for: dominant)
        let gap = progress.remaining

        guard gap > 0 else { return 100 }
        return min(100, max(0, Int(round((expectedNetProfit / gap) * 100))))
    }

    static func targetDirective(goals: WealthGoalVector, expectedNetProfit: Double) -> String {
        let dominant = goals.dominantTarget
        let gap = goals.progress(for: dominant).remaining
        let pressure = goals.pressure(for: dominant)

        if gap <= 0 {
            return "TARGET ALREADY COVERED"
        }

        switch (pressure, expectedNetProfit) {
        case (0.90..., 50...): return "STRONG \(dominant) RECOVERY FIT"
        case (0.90..., 20...): return "GOOD \(dominant) RECOVERY FIT"
        case (0.65..., 50...): return "STRONG \(dominant) POTENTIAL"
        case (0.65..., 20...): return "GOOD \(dominant) POTENTIAL"
        case (_, 20..<50): return "MODEST \(dominant) POTENTIAL"
        case (_, 8..<20): return "LIGHT \(dominant) EDGE"
        default: return "LIGHT PROFIT EDGE"
        }
    }

    static func aggressionMode(for goals: WealthGoalVector) -> WealthAggressionMode {
        if goals.tradingPressure >= 0.32 || goals.dailyPressure >= 0.85 || goals.daily.isNegative {
            return .aggressive
        }
        if goals.tradingPressure <= 0.08 && goals.daily.percent >= 1 && !goals.daily.isNegative {
            return .protect
        }
        return .moderate
    }

    static func hungerMode(for goals: WealthGoalVector, mode: WealthAggressionMode) -> WealthHungerMode {
        switch mode {
        case .aggressive: return goals.tradingPressure >= 0.30 || goals.daily.isNegative ? .press : .stalk
        case .moderate: return .stalk
        case .protect: return .protect
        }
    }

    static func marketRegime(for blueprints: [OpportunityBlueprint], goals: WealthGoalVector) -> WealthMarketRegime {
        let averageFlow = blueprints.map(\.sectorFlow).reduce(0, +) / Double(max(blueprints.count, 1))
        let averageRisk = blueprints.map(\.risk).reduce(0, +) / Double(max(blueprints.count, 1))
        let balance = averageFlow - averageRisk + (goals.tradingPressure * 6)

        if balance >= 28 { return .riskOn }
        if balance <= 12 { return .defensive }
        return .balanced
    }

    static func targetPressureLabel(_ goals: WealthGoalVector) -> String {
        if goals.daily.isNegative {
            return "RECOVERY TARGET PRESSURE"
        }

        switch goals.tradingPressure {
        case 0.30...: return "TARGET GUIDED"
        case 0.14..<0.30: return "LIGHT TARGET GUIDE"
        default: return "RESEARCH FIRST"
        }
    }

    static func makeBrainSnapshot(
        goals: WealthGoalVector,
        regime: WealthMarketRegime,
        mode: WealthAggressionMode,
        hunger: WealthHungerMode,
        hottest: Opportunity?
    ) -> WealthBrainSnapshot {
        WealthEngineDirectiveText.makeBrainSnapshot(
            goals: goals,
            regime: regime,
            mode: mode,
            hunger: hunger,
            hottest: hottest
        )
    }
}
