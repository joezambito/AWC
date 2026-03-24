import Foundation

struct WealthBrainLearningBias: Hashable {
    let qualityLift: Double
    let confidenceLift: Double
    let rewardLift: Double
    let riskPenalty: Double

    static let neutral = WealthBrainLearningBias(
        qualityLift: 0,
        confidenceLift: 0,
        rewardLift: 0,
        riskPenalty: 0
    )
}

struct WealthBrainFeatureSnapshot: Identifiable, Hashable {
    let id = UUID()
    let symbol: String
    let rank: Int
    let trend: String
    let momentum: String
    let pattern: String
    let smartMoney: String
    let event: String
    let execution: String
    let portfolioFit: String
    let anomaly: String
    let qualityLift: Double
    let confidenceLift: Double
    let rewardLift: Double
    let riskPenalty: Double
    let timestamp: Date
}

struct WealthBrainModelState: Hashable {
    let modelVersion: String
    let featureSnapshots: Int
    let activatedBrainItems: Int
    let topSymbol: String
    let computeMode: String
    let trainingState: String
    let governanceState: String
    let readiness: String
    let anomalyWatch: String
    let dataReadiness: String

    static let placeholder = WealthBrainModelState(
        modelVersion: "BRAIN-V2",
        featureSnapshots: 0,
        activatedBrainItems: 0,
        topSymbol: "--",
        computeMode: "STAGED",
        trainingState: "ADAPTIVE",
        governanceState: "GUARDED",
        readiness: "DEMO READY",
        anomalyWatch: "STABLE",
        dataReadiness: "WAITING DATA"
    )
}
