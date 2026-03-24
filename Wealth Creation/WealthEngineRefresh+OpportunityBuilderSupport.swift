import Foundation

extension WealthEngineRefreshRanking {
    static func stagedShareCount(
        proposedShares: Int,
        price: Double,
        buyingPower: Double,
        score: Int,
        confidence: Int,
        decision: WealthDecisionBias,
        goals: WealthGoalVector,
        regime: WealthMarketRegime,
        holdings: [Holding],
        sector: String,
        advanced: WealthAdvancedSignalProfile
    ) -> Int {
        let cappedShares = WealthEngineStore.cappedShareCount(
            proposedShares: proposedShares,
            price: price,
            buyingPower: buyingPower
        )
        let allocationPercent = WealthEngineStore.dynamicAllocationPercent(
            score: score,
            confidence: confidence,
            decision: decision,
            goals: goals,
            regime: regime,
            holdings: holdings,
            sector: sector,
            advanced: advanced
        )

        return WealthEngineStore.sizedShares(
            maxAffordableShares: cappedShares,
            allocationPercent: allocationPercent,
            decision: decision
        )
    }

    static func pricingContext(
        shares: Int,
        price: Double,
        expectedProfit: Double
    ) -> WealthOpportunityPricingContext {
        let subtotal = Double(shares) * price
        let buyFee = WealthScoringEngine.feeEstimate(for: subtotal)
        let sellFee = WealthScoringEngine.feeEstimate(for: subtotal + expectedProfit)
        let expectedNetProfit = max(0, expectedProfit - (buyFee + sellFee))
        let totalCost = subtotal + buyFee

        return WealthOpportunityPricingContext(
            totalCost: totalCost,
            buyFee: buyFee,
            expectedNetProfit: expectedNetProfit,
            capitalEfficiency: expectedNetProfit / max(1, totalCost)
        )
    }
}
