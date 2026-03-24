import Foundation

extension WealthEngineRefreshRanking {
    @MainActor
    static func buildDirectiveContext(
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
        brokerCooldownActive: Bool,
        advanced: WealthAdvancedSignalProfile,
        scoreResult: (score: Int, confidence: Int, safety: Int, expectedProfit: Double, shares: Int, fee: Double),
        decision: WealthDecisionBias,
        rotation: (bias: WealthRotationBias, reason: String),
        stagedShares: Int,
        pricing: WealthOpportunityPricingContext,
        selectionMode: WealthAggressionMode
    ) -> WealthOpportunityDirectiveContext {
        let rewardRiskRatio = WealthAISafeguards.rewardRiskRatio(
            expectedNetProfit: pricing.expectedNetProfit,
            totalCost: pricing.totalCost,
            risk: blueprint.risk
        )
        let positionLimit = WealthAISafeguards.positionLimit(for: selectionMode)
        let sectorLimit = WealthAISafeguards.sectorLimit(for: selectionMode)
        let sourceReliabilityScore = WealthEngineStore.sourceReliabilityScore(for: blueprint)
        let shareReliabilityScore = WealthEngineStore.shareReliabilityScore(
            for: blueprint,
            confidence: scoreResult.confidence,
            safety: scoreResult.safety
        )
        let trustState = WealthEngineStore.trustState(
            sourceReliability: sourceReliabilityScore,
            shareReliability: shareReliabilityScore
        )
        let executionStyle = WealthEngineStore.executionStyle(
            decision: decision,
            rotation: rotation.bias,
            mode: selectionMode,
            regime: regime,
            confidence: scoreResult.confidence,
            sessionOpen: sessionState.canTradeNow,
            advanced: advanced
        )
        let permission = WealthEngineStore.permissionState(
            score: scoreResult.score,
            confidence: scoreResult.confidence,
            decision: decision,
            buyingPower: buyingPower,
            totalCost: pricing.totalCost,
            expectedNetProfit: pricing.expectedNetProfit,
            spreadBps: blueprint.spreadBps,
            slippageRisk: blueprint.slippageRisk,
            risk: blueprint.risk,
            symbol: blueprint.symbol,
            market: blueprint.market,
            killSwitch: WealthProtectionSettingsStore.shared.killSwitch,
            sessionOpen: sessionState.canTradeNow,
            dataQuality: blueprint.dataQualityLabel,
            dataAge: blueprint.dataAge,
            priceChangePercent: blueprint.priceChangePercent,
            rotation: rotation.bias,
            duplicateExposureCount: duplicateExposureCount,
            trustState: trustState,
            advanced: advanced,
            timeWindow: blueprint.timeWindow,
            earningsEventRisk: blueprint.earningsEventRisk,
            macroEventRisk: blueprint.macroEventRisk,
            rewardRiskRatio: rewardRiskRatio,
            currentOpenPositions: currentOpenPositions,
            positionLimit: positionLimit,
            maxSectorExposure: sectorLimit,
            dailyLossLocked: dailyLossLocked,
            marketWideBrake: marketWideBrake,
            brokerCooldownActive: brokerCooldownActive
        )
        let hungerMode = WealthEngineStore.hungerMode(for: goals, mode: selectionMode)
        let allocationPercent = WealthEngineStore.dynamicAllocationPercent(
            score: scoreResult.score,
            confidence: scoreResult.confidence,
            decision: decision,
            goals: goals,
            regime: regime,
            holdings: holdings,
            sector: blueprint.sector,
            advanced: advanced
        )
        let positionSizePercent = buyingPower > 0
            ? Int(round((Double(stagedShares) * blueprint.price / buyingPower) * 100))
            : 0
        let conviction = WealthEngineStore.convictionLevel(
            for: scoreResult.score,
            confidence: scoreResult.confidence,
            decision: decision
        )
        let commandText = WealthEngineStore.commandText(
            decision: decision,
            permission: permission,
            rotation: rotation.bias,
            executionStyle: executionStyle,
            symbol: blueprint.symbol
        )
        let targetDirective = WealthEngineStore.targetDirective(
            goals: goals,
            expectedNetProfit: pricing.expectedNetProfit
        )
        let targetCoveragePercent = WealthEngineStore.targetCoveragePercent(
            goals: goals,
            expectedNetProfit: pricing.expectedNetProfit
        )
        let priorityScore = WealthEngineStore.priorityScore(
            score: scoreResult.score,
            confidence: scoreResult.confidence,
            expectedNetProfit: pricing.expectedNetProfit,
            capitalEfficiency: pricing.capitalEfficiency,
            timeWindow: blueprint.timeWindow,
            decision: decision,
            permission: permission,
            rotation: rotation.bias,
            mode: selectionMode,
            hunger: hungerMode,
            goals: goals,
            trustState: trustState,
            sourceReliability: sourceReliabilityScore,
            shareReliability: shareReliabilityScore,
            dataQuality: blueprint.dataQualityLabel,
            advanced: advanced
        )
        let trustReason = WealthEngineStore.trustReason(
            for: blueprint,
            sourceReliability: sourceReliabilityScore,
            shareReliability: shareReliabilityScore,
            trustState: trustState,
            advanced: advanced
        )

        return WealthOpportunityDirectiveContext(
            trustState: trustState,
            executionStyle: executionStyle,
            permission: permission,
            hungerMode: hungerMode,
            allocationPercent: allocationPercent,
            positionSizePercent: positionSizePercent,
            conviction: conviction,
            commandText: commandText,
            targetDirective: targetDirective,
            targetCoveragePercent: targetCoveragePercent,
            sourceReliabilityScore: sourceReliabilityScore,
            shareReliabilityScore: shareReliabilityScore,
            priorityScore: priorityScore,
            trustReason: trustReason
        )
    }
}
