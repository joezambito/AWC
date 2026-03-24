import Foundation

extension WealthAdvancedBrainEngine {
    private static func eventBias(catalyst: Double, newsScore: Double, sourceText: String, intelligenceText: String) -> Int {
        var score = Int(round((catalyst * 0.07) + (newsScore * 0.04) - 7))
        if containsAny(sourceText, ["NEWS", "CATALYST", "EARNINGS", "MOMENTUM CATALYST"]) { score += 4 }
        if containsAny(intelligenceText, ["TRANSCRIPT", "CONFERENCE", "RESEARCH BOT"]) { score += 3 }
        if containsAny(sourceText, ["NONE", "INSUFFICIENT DATA"]) { score -= 4 }
        return score
    }

    private static func eventBias(
        catalyst: Double,
        newsScore: Double,
        filingStrength: Double,
        insiderStrength: Double,
        sourceText: String,
        intelligenceText: String,
        isEnabled: (String) -> Bool,
        dataAge: TimeInterval,
        reviewSummary: String
    ) -> Int {
        let structuralLift =
            (isEnabled("Event Calendar Engine") ? filingStrength * 0.04 : 0)
            + (isEnabled("News NLP") ? insiderStrength * 0.03 : 0)
        var score = eventBias(
            catalyst: catalyst + structuralLift,
            newsScore: isEnabled("News NLP") ? newsScore : 0,
            sourceText: sourceText,
            intelligenceText: intelligenceText
        )
        if isEnabled("Transcript Intelligence") && containsAny(intelligenceText + reviewSummary.uppercased(), ["TRANSCRIPT", "GUIDANCE", "MANAGEMENT", "EARNINGS CALL"]) {
            score += 3
        }
        if isEnabled("Event Calendar Engine") && containsAny(sourceText + intelligenceText, ["EARNINGS", "FDA", "PRODUCT EVENT", "MACRO"]) {
            score += 4
        }
        if isEnabled("Catalyst Decay Model") && dataAge >= 86_400 {
            score -= 4
        }
        if isEnabled("Narrative Shift Detection") && containsAny(reviewSummary.uppercased() + intelligenceText, ["NARRATIVE SHIFT", "RE-RATING", "TURNAROUND", "GUIDANCE RESET"]) {
            score += 4
        }
        return score
    }

    private static func executionBias(
        blueprint: OpportunityBlueprint,
        regime: WealthMarketRegime,
        settings: WealthBehaviorSettingsStore,
        sectorExposure: Int,
        isEnabled: (String) -> Bool
    ) -> Int {
        var score = 0
        if isEnabled("Order Type Selection") && blueprint.timeWindow == "HOURS" { score += 3 }
        if blueprint.dataQualityLabel == "FRESH" { score += 4 }
        if blueprint.capitalFitLabel.contains("EASY") || blueprint.capitalFitLabel.contains("GOOD") { score += 3 }
        if blueprint.speedLabel.contains("ACTIVE") || blueprint.speedLabel.contains("FAST") { score += 2 }
        if blueprint.risk > 35 { score -= 4 }
        if regime == .defensive && blueprint.timeWindow == "HOURS" { score -= 3 }
        if sectorExposure >= 2 { score -= 2 }
        if settings.buyGate >= 68 { score -= 1 }
        if isEnabled("Broker Route Selection") && blueprint.market.uppercased().contains("US") { score += 1 }
        if isEnabled("Execution Slippage Tracker") && blueprint.price >= 30 && blueprint.price <= 300 { score += 1 }
        if isEnabled("Cancel / Replace Logic") && blueprint.dataQualityLabel == "FRESH" { score += 1 }
        if isEnabled("Multi-Leg Coordination") && blueprint.timeWindow == "DAYS" { score += 1 }
        return score
    }

    private static func portfolioFitBias(
        blueprint: OpportunityBlueprint,
        goals: WealthGoalVector,
        sectorExposure: Int,
        holdings: [Holding],
        isEnabled: (String) -> Bool
    ) -> Int {
        var score = 0
        if isEnabled("Campaign / Goal Alignment Engine") {
            if blueprint.targetFitLabel.contains("COMP") || blueprint.targetFitLabel.contains("TARGET") { score += 2 }
            if blueprint.targetFitLabel.contains("MISSION") && goals.dominantTarget == "MISSION" { score += 2 }
        }
        if isEnabled("Portfolio Optimizer") && blueprint.capitalFitLabel.contains("EASY") { score += 3 }
        if isEnabled("Exposure Balancer") && holdings.contains(where: { $0.market != blueprint.market }) { score += 2 }
        if isEnabled("Capital Rotation Planner") && blueprint.speedLabel.contains("FAST") { score += 2 }
        if blueprint.capitalFitLabel.contains("HEAVY") { score -= 2 }
        if isEnabled("Correlation / Concentration Controls") || isEnabled("Portfolio Heat Map") {
            score -= sectorExposure * 3
        }
        return score
    }

    private static func anomalyPenalty(
        blueprint: OpportunityBlueprint,
        sourceText: String,
        intelligenceText: String,
        negativeTape: Double,
        regime: WealthMarketRegime,
        isEnabled: (String) -> Bool
    ) -> Int {
        var penalty = 0
        if blueprint.dataQualityLabel == "STALE" { penalty += 10 }
        if blueprint.dataQualityLabel == "AGING" { penalty += 5 }
        if blueprint.risk >= 45 { penalty += 6 }
        if negativeTape >= 3 { penalty += 4 }
        if blueprint.timeWindow == "UNKNOWN" { penalty += 5 }
        if containsAny(sourceText, ["THIN FEED", "INSUFFICIENT DATA"]) { penalty += 6 }
        if containsAny(intelligenceText, ["NO EXTRA INTEL"]) { penalty += 2 }
        if isEnabled("Liquidity / Slippage Controls") && blueprint.price < 1.5 { penalty += 6 }
        if isEnabled("Execution Safety Layer") && blueprint.capitalFitLabel.contains("HEAVY") { penalty += 4 }
        if isEnabled("Tail-Risk Overrides") && regime == .defensive && blueprint.timeWindow == "HOURS" { penalty += 4 }
        if isEnabled("Anomaly Detection") && abs(blueprint.priceChangePercent) >= 5 { penalty += 5 }
        return penalty
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func weightedAverage(_ pairs: (Double, Double)...) -> Double {
        let weighted = pairs.reduce(0) { $0 + ($1.0 * $1.1) }
        let weight = pairs.reduce(0) { $0 + $1.1 }
        guard weight > 0 else { return 0 }
        return weighted / weight
    }
}
