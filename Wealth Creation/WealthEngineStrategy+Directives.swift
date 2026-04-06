import SwiftUI

extension WealthEngineStore {
    static func decisionBias(
        for score: Int,
        confidence: Int,
        safety _: Int,
        expectedProfit: Double,
        timeWindow: String,
        dataQuality: String,
        priceChangePercent: Double,
        advanced: WealthAdvancedSignalProfile
    ) -> WealthDecisionBias {
        WealthBuyDecisionRules.decisionBias(
            score: score,
            confidence: confidence,
            safety: 0,
            expectedProfit: expectedProfit,
            timeWindow: timeWindow,
            dataQuality: dataQuality,
            priceChangePercent: priceChangePercent,
            advanced: advanced
        )
    }

    static func buyReason(
        for blueprint: OpportunityBlueprint,
        score: Int,
        confidence: Int,
        mode: WealthAggressionMode,
        goals: WealthGoalVector,
        advanced: WealthAdvancedSignalProfile
    ) -> String {
        WealthEngineDirectiveText.buyReason(
            blueprint: blueprint,
            score: score,
            confidence: confidence,
            mode: mode,
            goals: goals,
            advanced: advanced
        )
    }

    static func warningReason(for blueprint: OpportunityBlueprint, score: Int, confidence: Int, regime: WealthMarketRegime) -> String {
        WealthBuyDecisionRules.warningReason(
            blueprint: blueprint,
            score: score,
            confidence: confidence,
            regime: regime
        )
    }
}
