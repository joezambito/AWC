import Foundation

@MainActor
extension WealthExternalDataStore {
    func bias(for blueprint: OpportunityBlueprint) -> WealthProviderBias {
        var quality = 0.0
        var confidence = 0.0
        var reward = 0.0
        var risk = 0.0

        if optionsFlowEnabled {
            quality += blueprint.optionsFlowStrength * 0.08
            reward += blueprint.optionsFlowStrength * 0.10
        }
        if darkPoolEnabled {
            quality += blueprint.darkPoolStrength * 0.09
            confidence += blueprint.darkPoolStrength * 0.06
        }
        if insiderEnabled {
            confidence += blueprint.insiderStrength * 0.07
            reward += blueprint.insiderStrength * 0.04
        }
        if filing13FEnabled {
            quality += blueprint.filingStrength * 0.06
            confidence += blueprint.filingStrength * 0.05
        }
        if earningsCalendarEnabled {
            risk += blueprint.earningsEventRisk * 0.08
        }
        if macroCalendarEnabled {
            risk += blueprint.macroEventRisk * 0.07
        }
        if liveOutcomeLearningEnabled {
            quality += blueprint.timeWindow == "HOURS" ? 2.5 : 0.8
            confidence += blueprint.timeWindow == "HOURS" ? 1.8 : 0.6
        }
        if backtestEngineEnabled {
            quality += blueprint.dataQualityLabel.uppercased() == "FRESH" ? 2.0 : 0.5
        }
        if retrainingEnabled, blueprint.probability >= 70 {
            quality += 2.2
            reward += 1.2
        }
        if researchMeshEnabled {
            let sourceText = ([blueprint.sourceTrigger, blueprint.reviewSummary] + blueprint.intelligenceDrivers)
                .joined(separator: " ")
                .uppercased()
            if sourceText.contains("TRANSCRIPT") { confidence += 2.0 }
            if sourceText.contains("RESEARCH") { quality += 1.5 }
            if sourceText.contains("CONSENSUS") { confidence += 1.2 }
        }

        return WealthProviderBias(
            qualityLift: quality,
            confidenceLift: confidence,
            rewardLift: reward,
            riskPenalty: risk
        )
    }

    var providerSources: [WealthProviderSource] {
        [
            makeSource("Options Flow", enabled: optionsFlowEnabled, detail: "Tape and skew"),
            makeSource("Dark Pool", enabled: darkPoolEnabled, detail: "Accumulation prints"),
            makeSource("Insider", enabled: insiderEnabled, detail: "Director behavior"),
            makeSource("13F", enabled: filing13FEnabled, detail: "Institutional positioning"),
            makeSource("Earnings", enabled: earningsCalendarEnabled, detail: "Calendar risk"),
            makeSource("Macro", enabled: macroCalendarEnabled, detail: "Rates and event risk"),
            makeSource("Outcome", enabled: liveOutcomeLearningEnabled, detail: "Trade learning"),
            makeSource("Backtest", enabled: backtestEngineEnabled, detail: "Replay memory"),
            makeSource("Retraining", enabled: retrainingEnabled, detail: "Adaptive weights"),
            makeSource("Research Mesh", enabled: researchMeshEnabled, detail: "Cross-source consensus")
        ]
    }

    var activeProviderCount: Int {
        providerSources.filter { $0.status == "LIVE" }.count
    }

    var readinessLabel: String {
        if activeProviderCount >= 8 { return "FULL STACK" }
        if activeProviderCount >= 5 { return "STRONG STACK" }
        return "BASE STACK"
    }

    private var feedClients: [any WealthExternalFeedClient] {
        var clients: [any WealthExternalFeedClient] = []
        if optionsFlowEnabled { clients.append(WealthOptionsFlowFeedClient()) }
        if darkPoolEnabled { clients.append(WealthDarkPoolFeedClient()) }
        if insiderEnabled { clients.append(WealthInsiderFeedClient()) }
        if filing13FEnabled { clients.append(WealthFiling13FFeedClient()) }
        if earningsCalendarEnabled { clients.append(WealthEarningsFeedClient()) }
        if macroCalendarEnabled { clients.append(WealthMacroFeedClient()) }
        return clients
    }

    private func makeSource(_ name: String, enabled: Bool, detail: String) -> WealthProviderSource {
        WealthProviderSource(
            name: name,
            status: enabled ? "LIVE" : "OFF",
            detail: detail,
            tint: enabled ? WealthTheme.green : WealthTheme.grey
        )
    }
}
