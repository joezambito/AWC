import Foundation

struct WealthOpportunityPricingContext {
    let totalCost: Double
    let buyFee: Double
    let expectedNetProfit: Double
    let capitalEfficiency: Double
}

struct WealthOpportunityBuildContext {
    let advanced: WealthAdvancedSignalProfile
    let scoreResult: (score: Int, confidence: Int, safety: Int, expectedProfit: Double, shares: Int, fee: Double)
    let decision: WealthDecisionBias
    let rotation: (bias: WealthRotationBias, reason: String)
    let stagedShares: Int
    let pricing: WealthOpportunityPricingContext
    let selectionMode: WealthAggressionMode
    let trustState: WealthTrustState
    let executionStyle: WealthExecutionStyle
    let permission: WealthPermissionState
    let hungerMode: WealthHungerMode
    let allocationPercent: Int
    let positionSizePercent: Int
    let conviction: WealthConvictionLevel
    let commandText: String
    let targetDirective: String
    let targetCoveragePercent: Int
    let sourceReliabilityScore: Int
    let shareReliabilityScore: Int
    let priorityScore: Int
    let trustReason: String
}
