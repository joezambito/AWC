import Foundation

extension WealthEngineRefreshRanking {
    @MainActor
    static func buildOpportunityContext(
        blueprint: OpportunityBlueprint,
        sessionState: MarketSessionState,
        goals: WealthGoalVector,
        behavior: WealthBehaviorSettingsStore,
        buyingPower: Double,
        regime: WealthMarketRegime,
        holdings: [Holding],
        duplicateExposureCount: Int,
        currentOpenPositions: Int,
        dailyLossLocked: Bool,
        marketWideBrake: Bool,
        brokerCooldownActive: Bool
    ) -> WealthOpportunityBuildContext {
        let signalContext = buildOpportunitySignalContext(
            blueprint: blueprint,
            goals: goals,
            behavior: behavior,
            regime: regime,
            holdings: holdings
        )

        let stagedShares = stagedShareCount(
            proposedShares: signalContext.scoreResult.shares,
            price: blueprint.price,
            buyingPower: buyingPower,
            score: signalContext.scoreResult.score,
            confidence: signalContext.scoreResult.confidence,
            decision: signalContext.decision,
            goals: goals,
            regime: regime,
            holdings: holdings,
            sector: blueprint.sector,
            advanced: signalContext.advanced
        )

        let pricing = pricingContext(
            shares: stagedShares,
            price: blueprint.price,
            expectedProfit: signalContext.scoreResult.expectedProfit
        )

        let selectionMode = WealthEngineStore.selectionMode(
            for: blueprint,
            score: signalContext.scoreResult.score,
            confidence: signalContext.scoreResult.confidence,
            expectedNetProfit: pricing.expectedNetProfit,
            goals: goals,
            advanced: signalContext.advanced,
            regime: regime
        )
        let directiveContext = buildDirectiveContext(
            blueprint: blueprint,
            sessionState: sessionState,
            goals: goals,
            behavior: behavior,
            buyingPower: buyingPower,
            regime: regime,
            holdings: holdings,
            duplicateExposureCount: duplicateExposureCount,
            currentOpenPositions: currentOpenPositions,
            dailyLossLocked: dailyLossLocked,
            marketWideBrake: marketWideBrake,
            brokerCooldownActive: brokerCooldownActive,
            advanced: signalContext.advanced,
            scoreResult: signalContext.scoreResult,
            decision: signalContext.decision,
            rotation: signalContext.rotation,
            stagedShares: stagedShares,
            pricing: pricing,
            selectionMode: selectionMode
        )

        return WealthOpportunityBuildContext(
            advanced: signalContext.advanced,
            scoreResult: signalContext.scoreResult,
            decision: signalContext.decision,
            rotation: signalContext.rotation,
            stagedShares: stagedShares,
            pricing: pricing,
            selectionMode: selectionMode,
            trustState: directiveContext.trustState,
            executionStyle: directiveContext.executionStyle,
            permission: directiveContext.permission,
            hungerMode: directiveContext.hungerMode,
            allocationPercent: directiveContext.allocationPercent,
            positionSizePercent: directiveContext.positionSizePercent,
            conviction: directiveContext.conviction,
            commandText: directiveContext.commandText,
            targetDirective: directiveContext.targetDirective,
            targetCoveragePercent: directiveContext.targetCoveragePercent,
            sourceReliabilityScore: directiveContext.sourceReliabilityScore,
            shareReliabilityScore: directiveContext.shareReliabilityScore,
            priorityScore: directiveContext.priorityScore,
            trustReason: directiveContext.trustReason
        )
    }
}
