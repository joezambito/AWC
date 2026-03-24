import Foundation

struct WealthOpportunitySignalContext {
    let advanced: WealthAdvancedSignalProfile
    let scoreResult: (score: Int, confidence: Int, safety: Int, expectedProfit: Double, shares: Int, fee: Double)
    let decision: WealthDecisionBias
    let rotation: (bias: WealthRotationBias, reason: String)
}

extension WealthEngineRefreshRanking {
    @MainActor
    static func buildOpportunitySignalContext(
        blueprint: OpportunityBlueprint,
        goals: WealthGoalVector,
        behavior: WealthBehaviorSettingsStore,
        regime: WealthMarketRegime,
        holdings: [Holding]
    ) -> WealthOpportunitySignalContext {
        let advanced = WealthAdvancedBrainEngine.profile(
            for: blueprint,
            goals: goals,
            regime: regime,
            settings: behavior,
            holdings: holdings
        )

        let scoreResult = WealthScoringEngine.score(
            for: blueprint,
            settings: behavior,
            goals: goals,
            regime: regime,
            holdings: holdings,
            advancedSignal: advanced
        )

        let decision = WealthEngineStore.decisionBias(
            for: scoreResult.score,
            confidence: scoreResult.confidence,
            safety: scoreResult.safety,
            expectedProfit: scoreResult.expectedProfit,
            timeWindow: blueprint.timeWindow,
            dataQuality: blueprint.dataQualityLabel,
            priceChangePercent: blueprint.priceChangePercent,
            advanced: advanced
        )

        let rotation = WealthEngineStore.rotationSignal(
            for: blueprint,
            score: scoreResult.score,
            confidence: scoreResult.confidence,
            decision: decision,
            holdings: holdings,
            settings: behavior
        )

        return WealthOpportunitySignalContext(
            advanced: advanced,
            scoreResult: scoreResult,
            decision: decision,
            rotation: rotation
        )
    }
}
