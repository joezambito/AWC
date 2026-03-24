import Foundation

extension WealthBrainStore {
    var computeModeLabel: String {
#if targetEnvironment(macCatalyst)
        return WealthBrainToggleStore.shared.runtimeMode == .demo ? "DESKTOP DEMO STACK" : "DESKTOP SUPERCHARGED"
#else
        return WealthBrainToggleStore.shared.runtimeMode == .demo ? "PHONE DEMO STACK" : "PHONE STAGED"
#endif
    }

    var trainingStateLabel: String {
        let toggles = WealthBrainToggleStore.shared
#if targetEnvironment(macCatalyst)
        if toggles.isEnabled(title: "Training the Model") && toggles.isEnabled(title: "Heavy Backtest / Training Jobs") {
            return "DEEP TRAINING ACTIVE"
        }
        if toggles.isEnabled(title: "Online Learning Memory") {
            return "DEEP ADAPTIVE MEMORY"
        }
        return "DESKTOP LEARNING"
#else
        if toggles.isEnabled(title: "Online Learning Memory") {
            return "LIGHT ADAPTIVE MEMORY"
        }
        return "PHONE LEARNING"
#endif
    }

    var governanceStateLabel: String {
        let toggles = WealthBrainToggleStore.shared
        if toggles.isEnabled(title: "Model Registry") &&
            toggles.isEnabled(title: "Explainability Layer") &&
            toggles.isEnabled(title: "Audit / Decision Trail") {
            return "FULLY AUDITED"
        }
        if toggles.isEnabled(title: "Explainability Layer") && toggles.isEnabled(title: "Audit / Decision Trail") {
            return "AUDITED"
        }
        if toggles.isEnabled(title: "Rollback / Safe Revert") {
            return "SAFE REVERT"
        }
        return "GUARDED"
    }

    func bias(for blueprint: OpportunityBlueprint) -> WealthBrainLearningBias {
        let toggles = WealthBrainToggleStore.shared
        let symbolLift = symbolStrength[blueprint.symbol, default: 0]
        let sectorLift = sectorStrength[blueprint.sector, default: 0]
        let blended = (symbolLift * 0.65) + (sectorLift * 0.35)

        let freshnessBonus: Double = {
            switch blueprint.dataQualityLabel.uppercased() {
            case "FRESH": return 2.8
            case "AGING": return 0.8
            default: return -2.0
            }
        }()

        let timeBias: Double = {
            switch blueprint.timeWindow {
            case "HOURS": return 3.5
            case "DAYS": return 1.2
            case "WEEKS": return -2.2
            default: return 0
            }
        }()

        let urgencyBias: Double = {
            let upper = blueprint.urgency.uppercased()
            if upper.contains("HIGH") || upper.contains("NOW") { return 2.5 }
            if upper.contains("MED") { return 1.0 }
            return 0
        }()

        let trainingLift = toggles.isEnabled(title: "Training the Model") ? min(3.5, abs(blended) * 0.18) : 0
        let featureStoreLift = toggles.isEnabled(title: "Historical Feature Store") && blueprint.analysisAge <= 3_600 ? 1.4 : 0
        let onlineLearningLift = toggles.isEnabled(title: "Online Learning Memory") ? min(2.2, max(-1.2, blended * 0.12)) : 0
        let totalQuality = blended + freshnessBonus + timeBias + urgencyBias + trainingLift + featureStoreLift + onlineLearningLift

        return WealthBrainLearningBias(
            qualityLift: totalQuality,
            confidenceLift: max(-4, min(8, totalQuality * 0.45)),
            rewardLift: max(-3, min(10, totalQuality * 0.7)),
            riskPenalty: totalQuality >= 0 ? 0 : min(6, abs(totalQuality) * 0.55)
        )
    }

    func learn(from opportunities: [Opportunity], holdings: [Holding]) {
        let toggles = WealthBrainToggleStore.shared
        let onlineLearningActive = toggles.isEnabled(title: "Online Learning Memory")
        let anomalyDetectionActive = toggles.isEnabled(title: "Anomaly Detection")
        let trainingActive = toggles.isEnabled(title: "Training the Model")

        for opportunity in opportunities.prefix(6) {
            let capitalEfficiency = opportunity.trueCost > 0
                ? opportunity.expectedNetProfit / opportunity.trueCost
                : 0
            let profitBias = min(8.0, max(-4.0, capitalEfficiency * 180))
            let rankBias = max(0.0, Double(8 - min(opportunity.rank, 8)))
            let confidenceBias = Double(opportunity.confidence - 60) * 0.08
            let trustBias: Double = {
                switch opportunity.trustState {
                case .verified: return 3.5
                case .usable: return 1.5
                case .caution: return -1.5
                case .weak: return -4.0
                }
            }()
            let permissionBias: Double = {
                switch opportunity.permission {
                case .go: return 4.0
                case .wait: return 0.5
                case .blocked: return -3.5
                }
            }()
            let timeBias: Double = {
                switch opportunity.timeWindow {
                case "HOURS": return 2.4
                case "DAYS": return 1.0
                case "WEEKS": return -1.8
                default: return 0
                }
            }()
            let anomalyPenalty = opportunity.advancedSignal.anomalyState == "STABLE" ? 0.0 : (anomalyDetectionActive ? 3.5 : 2.5)
            let trainingBias = trainingActive ? min(2.4, max(-1.0, opportunity.advancedSignal.qualityLift * 0.05)) : 0
            let delta = profitBias + rankBias + confidenceBias + trustBias + permissionBias + timeBias + trainingBias - anomalyPenalty

            let symbolDecay = onlineLearningActive ? 0.90 : 0.84
            let sectorDecay = onlineLearningActive ? 0.92 : 0.88
            symbolStrength[opportunity.symbol] = boundedMemory(symbolStrength[opportunity.symbol, default: 0] * symbolDecay + delta)
            sectorStrength[opportunity.sector] = boundedMemory(sectorStrength[opportunity.sector, default: 0] * sectorDecay + (delta * 0.55))
        }

        for holding in holdings {
            let pnlRatio = holding.costBasis > 0 ? (holding.unrealizedPnL / holding.costBasis) : 0
            let realizedBias = min(8.0, max(-8.0, pnlRatio * 120))
            let confidenceBias = Double(holding.confidence - 60) * 0.06
            let qualityBias = holding.aiScore <= 20 ? 2.4 : (holding.aiScore <= 40 ? 0.8 : -1.6)
            let anomalyPenalty = anomalyDetectionActive && holding.netReturnPercent < -3 ? 1.6 : 0
            let delta = realizedBias + confidenceBias + qualityBias - anomalyPenalty

            symbolStrength[holding.symbol] = boundedMemory(symbolStrength[holding.symbol, default: 0] * 0.90 + delta)
            sectorStrength[holding.sector] = boundedMemory(sectorStrength[holding.sector, default: 0] * 0.92 + (delta * 0.45))
        }
    }

    func boundedMemory(_ value: Double) -> Double {
        min(12, max(-10, value))
    }

    func readinessLabel(base: String) -> String {
        let coverage = WealthBrainToggleStore.shared.activationCoverage
        switch coverage {
        case 0.95...:
            return "\(base) FULL STACK"
        case 0.75...:
            return "\(base) EXPANDED"
        case 0.55...:
            return "\(base) GROWING"
        default:
            return base
        }
    }
}
