import Foundation

extension WealthAdvancedBrainEngine {
    static func executionScore(
        for blueprint: OpportunityBlueprint,
        regime: WealthMarketRegime,
        settings: WealthBehaviorSettingsStore
    ) -> Int {
        var score = 0

        if blueprint.dataQualityLabel.uppercased() == "FRESH" { score += 3 }
        if capitalFits(blueprint.capitalFitLabel) { score += 2 }
        if blueprint.spreadBps > 35 { score -= 3 }
        if blueprint.slippageRisk > 45 { score -= 3 }
        if blueprint.risk >= 50 { score -= 2 }
        if settings.buyGate >= 68 { score -= 1 }
        if regime == .defensive && blueprint.timeWindow == "HOURS" { score -= 2 }

        return score
    }

    static func portfolioScore(
        for blueprint: OpportunityBlueprint,
        goals: WealthGoalVector,
        holdings: [Holding]
    ) -> Int {
        let sectorExposure = holdings.filter { $0.sector == blueprint.sector }.count
        let marketExposure = holdings.filter { $0.market == blueprint.market }.count

        var score = 0
        if sectorExposure == 0 {
            score += 3
        } else if sectorExposure >= 2 {
            score -= 4
        }

        if marketExposure >= 3 { score -= 2 }
        if blueprint.targetFitLabel.uppercased().contains(goals.dominantTarget) { score += 2 }
        if blueprint.capitalFitLabel.uppercased().contains("HEAVY") { score -= 2 }

        return score
    }

    static func capitalFits(_ capitalFitLabel: String) -> Bool {
        let text = capitalFitLabel.uppercased()
        return text.contains("EASY") || text.contains("GOOD")
    }

    static func bounded(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }
}
