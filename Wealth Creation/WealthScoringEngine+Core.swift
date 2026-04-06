import Foundation

extension WealthScoringEngine {
    @MainActor
    static func score(
        for blueprint: OpportunityBlueprint,
        settings: WealthBehaviorSettingsStore,
        goals: WealthGoalVector,
        regime: WealthMarketRegime,
        holdings: [Holding],
        advancedSignal: WealthAdvancedSignalProfile? = nil
    ) -> (score: Int, confidence: Int, safety: Int, expectedProfit: Double, shares: Int, fee: Double) {
        let advanced = advancedSignal ?? WealthAdvancedBrainEngine.profile(
            for: blueprint,
            goals: goals,
            regime: regime,
            settings: settings,
            holdings: holdings
        )

        let learning = WealthBrainStore.shared.bias(for: blueprint)
        let provider = WealthExternalDataStore.shared.bias(for: blueprint)
        let toggles = WealthBrainToggleStore.shared
        let isEnabled: (String) -> Bool = { toggles.isEnabled(title: $0) }

        let liquidity = liquidityQuality(for: blueprint)
        let spread = spreadPenalty(for: blueprint)
        let slippage = slippagePenalty(for: blueprint)
        let calendar = calendarPenalty(for: blueprint)
        let smartMoney = smartMoneyBonus(for: blueprint)
        let sectorPenalty = sectorExposurePenalty(for: blueprint, holdings: holdings)
        let featureLift = featureEngineeringLift(for: blueprint, advanced: advanced, isEnabled: isEnabled)
        let clusterLift = clusteringLift(for: blueprint, holdings: holdings, isEnabled: isEnabled)
        let regimeLift = regimeClassificationLift(for: blueprint, regime: regime, advanced: advanced, isEnabled: isEnabled)
        let dataLift = dataInfrastructureLift(for: blueprint, isEnabled: isEnabled)
        let brokerLift = brokerStateLift(isEnabled: isEnabled)
        let heatPenalty = portfolioHeatPenalty(for: blueprint, holdings: holdings, isEnabled: isEnabled)

        let learningAmplifier = isEnabled("Online Learning Memory") ? 1.15 : 1.0
        let providerAmplifier = isEnabled("Alternative Data Routing") ? 1.10 : 1.0
        let targetAlignmentLift: Double = {
            let fit = blueprint.targetFitLabel.uppercased()
            let dominant = goals.dominantTarget
            var lift = goals.tradingPressure * 6

            if fit.contains(dominant) {
                lift += 10
            }

            if dominant == "DAILY" && fit.contains("TARGET") {
                lift += 6
            } else if dominant == "COMPOUND" && (fit.contains("COMP") || fit.contains("TARGET")) {
                lift += 6
            } else if dominant == "MISSION" && fit.contains("MISSION") {
                lift += 8
            }

            if fit.contains("WATCH") {
                lift -= 4
            }

            return lift
        }()

        let positiveSignalTotal =
            (blueprint.technical * 0.24) +
            (blueprint.fundamental * 0.12) +
            (blueprint.alternative * 0.11) +
            (blueprint.social * 0.08) +
            (blueprint.institutional * 0.16) +
            (blueprint.catalyst * 0.14) +
            (blueprint.sectorFlow * 0.15) +
            smartMoney +
            max(0, (liquidity - 55) * 0.16) +
            featureLift +
            clusterLift +
            dataLift +
            brokerLift

        let riskPenaltyTotal =
            (blueprint.risk * 0.55) +
            spread +
            slippage +
            calendar +
            sectorPenalty +
            heatPenalty

        let rawQuality =
            positiveSignalTotal -
            riskPenaltyTotal -
            (settings.feeEdgeMult * 4) +
            (Double(settings.buyGate - 50) * 0.35) +
            ((settings.targetFit * 25) + (goals.tradingPressure * 4) + targetAlignmentLift) +
            regimeBias(for: blueprint, regime: regime) +
            regimeLift +
            timeWindowBias(for: blueprint.timeWindow) +
            max(0, (blueprint.probability - blueprint.risk) * 0.08) +
            (advanced.qualityLift - advanced.riskPenalty) +
            ((learning.qualityLift - learning.riskPenalty) * learningAmplifier) +
            ((provider.qualityLift - provider.riskPenalty) * providerAmplifier)

        let masterQuality = clamp(50 + ((rawQuality - 50) * 0.45), min: 1, max: 99)
        let baseScore = clamp(100 - masterQuality, min: 1, max: 100)
        let stalenessPenalty = stalenessPenalty(for: blueprint.dataAge)

        let confidenceBase =
            52 +
            (blueprint.technical * 0.12) +
            (blueprint.institutional * 0.11) +
            (blueprint.catalyst * 0.09) -
            (blueprint.risk * 0.07) +
            (goals.tradingPressure * 2) +
            max(0, targetAlignmentLift * 0.18) +
            advanced.confidenceLift +
            (learning.confidenceLift * learningAmplifier) +
            (provider.confidenceLift * providerAmplifier) +
            max(0, (liquidity - 60) * 0.10) -
            stalenessPenalty -
            (calendar * 0.45) +
            max(0, regimeLift * 0.45) +
            max(0, dataLift * 0.25)

        let confidence = clampInt(Int(round(confidenceBase)), min: 1, max: 100)
        let lowerIsBetterScore = clampInt(Int(round(baseScore)), min: 1, max: 100)

        let safetyBase =
            100 -
            blueprint.risk -
            (advanced.riskPenalty * 0.55) -
            ((learning.riskPenalty * learningAmplifier) * 0.45) -
            ((provider.riskPenalty * providerAmplifier) * 0.45) -
            (spread * 0.45) -
            (slippage * 0.55) -
            (calendar * 0.35) -
            (heatPenalty * 0.35)
        let safety = clampInt(Int(round(safetyBase)), min: 25, max: 97)

        let expectedGross = expectedGrossProfit(
            blueprint: blueprint,
            liquidity: liquidity,
            spread: spread,
            slippage: slippage,
            calendar: calendar,
            smartMoney: smartMoney,
            advanced: advanced,
            learning: learning,
            provider: provider,
            learningAmplifier: learningAmplifier,
            providerAmplifier: providerAmplifier,
            clusterLift: clusterLift
        )

        let shares = suggestedShareCount(
            blueprint: blueprint,
            masterQuality: masterQuality,
            advanced: advanced,
            learning: learning,
            liquidity: liquidity
        )
        let subtotal = Double(shares) * blueprint.price

        return (lowerIsBetterScore, confidence, safety, expectedGross, shares, feeEstimate(for: subtotal))
    }
}

