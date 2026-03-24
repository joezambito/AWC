import Foundation

extension WealthScoringEngine {
    static func stalenessPenalty(for dataAge: TimeInterval) -> Double {
        if dataAge >= 86_400 { return 18 }
        if dataAge >= 3_600 { return 8 }
        return 0
    }

    static func expectedGrossProfit(
        blueprint: OpportunityBlueprint,
        liquidity: Double,
        spread: Double,
        slippage: Double,
        calendar: Double,
        smartMoney: Double,
        advanced: WealthAdvancedSignalProfile,
        learning: WealthBrainLearningBias,
        provider: WealthProviderBias,
        learningAmplifier: Double,
        providerAmplifier: Double,
        clusterLift: Double
    ) -> Double {
        let probabilityFactor = clamp(blueprint.probability / 100, min: 0, max: 1)
        let grossBaseReward = probabilityFactor * blueprint.price * rewardFactor(for: blueprint.timeWindow)
        let grossPenalty = (spread * 0.40) + (slippage * 0.55) + (calendar * 0.45)

        return max(
            12,
            grossBaseReward +
                advanced.rewardLift +
                (learning.rewardLift * learningAmplifier) +
                (provider.rewardLift * providerAmplifier) +
                (smartMoney * 0.55) +
                max(0, (liquidity - 50) * 0.18) +
                max(0, clusterLift * 0.35) -
                grossPenalty
        )
    }

    static func suggestedShareCount(
        blueprint: OpportunityBlueprint,
        masterQuality: Double,
        advanced: WealthAdvancedSignalProfile,
        learning: WealthBrainLearningBias,
        liquidity: Double
    ) -> Int {
        let rawShares = Int(round(
            clamp(masterQuality / 12, min: 2, max: 10) +
            clamp(advanced.qualityLift / 20, min: -1, max: 2) +
            clamp(learning.qualityLift / 12, min: -1.5, max: 2) +
            clamp((liquidity - 55) / 18, min: -1, max: 1)
        ))

        return max(1, rawShares)
    }

    static func regimeBias(for blueprint: OpportunityBlueprint, regime: WealthMarketRegime) -> Double {
        switch regime {
        case .riskOn:
            return blueprint.timeWindow == "HOURS" ? 6 : 2
        case .balanced:
            return 0
        case .defensive:
            return blueprint.timeWindow == "HOURS" ? -7 : -2
        }
    }

    static func timeWindowBias(for timeWindow: String) -> Double {
        switch timeWindow {
        case "HOURS": return 12
        case "DAYS": return 2
        case "WEEKS": return -10
        default: return -4
        }
    }

    static func rewardFactor(for timeWindow: String) -> Double {
        switch timeWindow {
        case "HOURS": return 0.24
        case "DAYS": return 0.18
        default: return 0.12
        }
    }
}
