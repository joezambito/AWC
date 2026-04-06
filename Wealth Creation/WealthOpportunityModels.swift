import Foundation
import SwiftUI

struct Opportunity: Identifiable, Hashable {
    var id: String { "\(symbol.uppercased())-\(market.uppercased())" }

    let rank: Int
    let symbol: String
    let market: String
    let sector: String
    let aiScore: Int
    let confidence: Int
    let safety: Int
    let probabilityOfSuccess: Int
    let newsScore: Int
    let recommendedShares: Int
    let price: Double
    let brokerFee: Double
    let expectedProfit: Double
    let prospect: String
    let timeToTarget: String
    let timeWindow: String
    let catalystBucket: String
    let sourceTrigger: String
    let dataOrigin: String
    let sourceSummary: String
    let reviewSummary: String
    let intelligenceDrivers: [String]
    let intelligenceChannels: [String]
    let urgency: String
    let priceChangePercent: Double
    let targetFitLabel: String
    let speedLabel: String
    let capitalFitLabel: String
    let dataQualityLabel: String
    let analysisTimestamp: Date
    let dataTimestamp: Date
    let lastRefreshTimestamp: Date
    let brokerName: String
    let orderState: OrderExecutionState
    let submittedPrice: Double
    let submittedShares: Int
    let actualExitPrice: Double = 0
    let actualRealizedProfit: Double = 0
    let actualRealizedNetProfit: Double = 0
    let completedAt: Date? = nil
    let decisionBias: WealthDecisionBias
    let aggressionMode: WealthAggressionMode
    let marketRegime: WealthMarketRegime
    let targetPressureLabel: String
    let capitalDisciplineLabel: String
    let allocationPercent: Int
    let positionSizePercent: Int
    let conviction: WealthConvictionLevel
    let permission: WealthPermissionState
    let rotationBias: WealthRotationBias
    let hungerMode: WealthHungerMode
    let executionStyle: WealthExecutionStyle
    let commandText: String
    let priorityScore: Int
    let targetDirective: String
    let targetCoveragePercent: Int
    let sourceReliabilityScore: Int
    let shareReliabilityScore: Int
    let optionsFlowStrength: Double
    let darkPoolStrength: Double
    let insiderStrength: Double
    let filingStrength: Double
    let earningsEventRisk: Double
    let macroEventRisk: Double
    let trustState: WealthTrustState
    let trustReason: String
    let buyReason: String
    let rotationReason: String
    let warningReason: String
    let advancedSignal: WealthAdvancedSignalProfile
    let previousAiScore: Int?
    let previousConfidence: Int?
}
