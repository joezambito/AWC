import Foundation

struct WealthAdvancedSignalProfile: Hashable {
    let trendState: String
    let momentumState: String
    let patternState: String
    let smartMoneyState: String
    let eventState: String
    let executionState: String
    let portfolioState: String
    let anomalyState: String
    let qualityLift: Double
    let confidenceLift: Double
    let rewardLift: Double
    let riskPenalty: Double

    static let neutral = WealthAdvancedSignalProfile(
        trendState: "TREND NEUTRAL",
        momentumState: "MOMENTUM FLAT",
        patternState: "PATTERN NEUTRAL",
        smartMoneyState: "SMART MONEY LIGHT",
        eventState: "EVENT NEUTRAL",
        executionState: "EXECUTION WATCH",
        portfolioState: "PORTFOLIO NEUTRAL",
        anomalyState: "STABLE",
        qualityLift: 0,
        confidenceLift: 0,
        rewardLift: 0,
        riskPenalty: 0
    )
}

enum WealthAdvancedBrainEngine {
    @MainActor
    static func profile(
        for blueprint: OpportunityBlueprint,
        goals: WealthGoalVector,
        regime: WealthMarketRegime,
        settings: WealthBehaviorSettingsStore,
        holdings: [Holding]
    ) -> WealthAdvancedSignalProfile {
        let trendScore = trendScore(for: blueprint, regime: regime)
        let momentumScore = momentumScore(for: blueprint)
        let patternScore = patternScore(for: blueprint)
        let smartMoneyScore = smartMoneyScore(for: blueprint)
        let eventScore = eventScore(for: blueprint)
        let executionScore = executionScore(for: blueprint, regime: regime, settings: settings)
        let portfolioScore = portfolioScore(for: blueprint, goals: goals, holdings: holdings)
        let anomalyScore = anomalyScore(for: blueprint, regime: regime)

        let qualityLift =
            (Double(trendScore) * 0.9) +
            (Double(momentumScore) * 0.6) +
            (Double(patternScore) * 0.8) +
            (Double(smartMoneyScore) * 0.9) +
            (Double(eventScore) * 0.65) +
            (Double(executionScore) * 0.6) +
            (Double(portfolioScore) * 0.5) -
            (Double(max(0, anomalyScore)) * 1.2)

        let confidenceLift =
            (Double(trendScore) * 0.45) +
            (Double(patternScore) * 0.55) +
            (Double(smartMoneyScore) * 0.60) +
            (Double(eventScore) * 0.40) -
            (Double(max(0, anomalyScore)) * 0.9)

        let rewardLift =
            (Double(momentumScore) * 0.55) +
            (Double(patternScore) * 0.55) +
            (Double(smartMoneyScore) * 0.70) +
            (Double(executionScore) * 0.35) -
            (Double(max(0, anomalyScore)) * 0.75)

        let riskPenalty = max(
            0,
            (Double(max(0, anomalyScore)) * 1.35) +
            (Double(max(0, -executionScore)) * 0.75) +
            (Double(max(0, -portfolioScore)) * 0.55)
        )

        return WealthAdvancedSignalProfile(
            trendState: trendState(for: trendScore),
            momentumState: momentumState(for: momentumScore),
            patternState: patternState(for: patternScore),
            smartMoneyState: smartMoneyState(for: smartMoneyScore),
            eventState: eventState(for: eventScore),
            executionState: executionState(for: executionScore),
            portfolioState: portfolioState(for: portfolioScore),
            anomalyState: anomalyState(for: anomalyScore),
            qualityLift: bounded(qualityLift, min: -18, max: 18),
            confidenceLift: bounded(confidenceLift, min: -10, max: 12),
            rewardLift: bounded(rewardLift, min: -10, max: 14),
            riskPenalty: bounded(riskPenalty, min: 0, max: 16)
        )
    }
}
