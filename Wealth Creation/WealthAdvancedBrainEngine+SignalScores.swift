import Foundation

extension WealthAdvancedBrainEngine {
    static func smartMoneyScore(for blueprint: OpportunityBlueprint) -> Int {
        var score = 0
        score += Int(round(blueprint.optionsFlowStrength / 16))
        score += Int(round(blueprint.darkPoolStrength / 15))
        score += Int(round(blueprint.insiderStrength / 18))
        score += Int(round(blueprint.filingStrength / 20))

        let text = ([blueprint.sourceTrigger] + blueprint.intelligenceDrivers + blueprint.intelligenceChannels)
            .joined(separator: " ")
            .uppercased()

        if text.contains("DARK POOL") { score += 2 }
        if text.contains("OPTIONS") { score += 2 }
        if text.contains("INSIDER") { score += 1 }
        if text.contains("DISTRIBUTION") { score -= 3 }

        return score
    }

    static func eventScore(for blueprint: OpportunityBlueprint) -> Int {
        let text = [blueprint.sourceTrigger, blueprint.reviewSummary, blueprint.catalystBucket]
            .joined(separator: " ")
            .uppercased()

        var score = 0
        if blueprint.catalyst >= 72 {
            score += 4
        } else if blueprint.catalyst >= 60 {
            score += 2
        }

        if blueprint.newsScore >= 75 { score += 2 }
        if text.contains("EARNINGS") || text.contains("GUIDANCE") || text.contains("CATALYST") { score += 2 }
        if blueprint.earningsEventRisk >= 55 || blueprint.macroEventRisk >= 60 { score -= 4 }
        if blueprint.dataAge >= 86_400 { score -= 2 }

        return score
    }

    static func anomalyScore(for blueprint: OpportunityBlueprint, regime: WealthMarketRegime) -> Int {
        var score = 0

        if blueprint.dataQualityLabel.uppercased() == "STALE" { score += 4 }
        if blueprint.dataQualityLabel.uppercased() == "AGING" { score += 2 }
        if abs(blueprint.priceChangePercent) >= 5 { score += 3 }
        if blueprint.risk >= 60 { score += 4 }
        if blueprint.capitalFitLabel.uppercased().contains("POOR") { score += 3 }
        if regime == .defensive && blueprint.timeWindow == "HOURS" { score += 2 }

        return score
    }
}
