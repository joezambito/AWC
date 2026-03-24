import SwiftUI

extension WealthEngineStore {
    static func priorityScore(
        score: Int,
        confidence: Int,
        expectedNetProfit: Double,
        capitalEfficiency: Double,
        timeWindow: String,
        decision: WealthDecisionBias,
        permission: WealthPermissionState,
        rotation: WealthRotationBias,
        mode: WealthAggressionMode,
        hunger: WealthHungerMode,
        goals: WealthGoalVector,
        trustState: WealthTrustState,
        sourceReliability: Int,
        shareReliability: Int,
        dataQuality: String,
        advanced: WealthAdvancedSignalProfile
    ) -> Int {
        var total = 0
        let toggles = WealthBrainToggleStore.shared
        total += max(0, 110 - score)
        total += min(30, confidence / 3)
        total += min(35, Int(round(expectedNetProfit)))
        total += min(24, max(0, Int(round(expectedNetProfit * 1.2))))
        total += min(8, Int(round(Double(targetCoveragePercent(goals: goals, expectedNetProfit: expectedNetProfit)) * 0.08)))
        total += min(20, sourceReliability / 5)
        total += min(20, shareReliability / 5)
        total += min(26, Int(round(capitalEfficiency * 220)))

        switch timeWindow {
        case "HOURS": total += 16
        case "DAYS": total += 8
        case "WEEKS": total -= 10
        default: total -= 6
        }

        switch decision {
        case .buy: total += 35
        case .hold: total += 12
        case .avoid: total -= 30
        }

        switch permission {
        case .go: total += 25
        case .wait: total -= 5
        case .blocked: total -= 40
        }

        switch rotation {
        case .rotate: total += 15
        case .add: total += 10
        case .keep: total += 4
        case .block: total -= 20
        }

        switch mode {
        case .moderate: total += 12
        case .aggressive: total += 6
        case .protect: total += 2
        }

        switch hunger {
        case .hunt: total += 18
        case .press: total += 10
        case .stalk: total += 4
        case .protect: total -= 8
        }

        switch trustState {
        case .verified: total += 22
        case .usable: total += 10
        case .caution: total -= 8
        case .weak: total -= 35
        }

        if dataQuality == "STALE" {
            total -= 25
        } else if dataQuality == "AGING" {
            total -= 10
        }

        if toggles.isEnabled(title: "Explainability Layer") {
            if advanced.trendState == "TRENDING STRONG" { total += 8 }
            if advanced.patternState == "PATTERN BULLISH" { total += 8 }
            if advanced.smartMoneyState == "SMART MONEY STRONG" { total += 10 }
            if advanced.eventState == "EVENT STRONG" { total += 8 }
            if advanced.portfolioState == "PORTFOLIO CROWDING" { total -= 10 }
            if advanced.anomalyState == "ANOMALY HIGH" { total -= 18 }
        }
        if toggles.isEnabled(title: "Model Registry"), decision == .buy, permission == .go {
            total += 6
        }
        if toggles.isEnabled(title: "Audit / Decision Trail"), trustState == .verified {
            total += 4
        }

        return total
    }

    static func selectionMode(
        for blueprint: OpportunityBlueprint,
        score: Int,
        confidence: Int,
        expectedNetProfit: Double,
        advanced: WealthAdvancedSignalProfile,
        regime: WealthMarketRegime
    ) -> WealthAggressionMode {
        let toggles = WealthBrainToggleStore.shared
        if regime == .defensive ||
            score >= 36 ||
            confidence < 68 ||
            advanced.anomalyState != "STABLE" ||
            blueprint.timeWindow == "WEEKS" {
            return .protect
        }

        if score <= 18 &&
            confidence >= 82 &&
            expectedNetProfit >= 18 &&
            advanced.smartMoneyState == "SMART MONEY STRONG" &&
            advanced.executionState == "EXECUTION CLEAN" {
            return .aggressive
        }

        if toggles.isEnabled(title: "Regime Classification Model") &&
            advanced.trendState == "TRENDING STRONG" &&
            advanced.eventState != "EVENT SOFT" &&
            regime == .riskOn {
            return .aggressive
        }

        return .moderate
    }
}
