import Foundation

@MainActor
extension WealthExternalDataStore {
    func bias(for blueprint: OpportunityBlueprint) -> WealthProviderBias {
        var quality = 0.0
        var confidence = 0.0
        var reward = 0.0
        var risk = 0.0
        var supportQuality = 0.0
        var supportConfidence = 0.0
        var supportReward = 0.0

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
            supportQuality += blueprint.timeWindow == "HOURS" ? 1.1 : 0.4
            supportConfidence += blueprint.timeWindow == "HOURS" ? 0.8 : 0.3
        }
        if backtestEngineEnabled {
            supportQuality += blueprint.dataQualityLabel.uppercased() == "FRESH" ? 0.8 : 0.2
        }
        if retrainingEnabled, blueprint.probability >= 70 {
            supportQuality += 0.9
            supportReward += 0.4
        }
        if researchMeshEnabled {
            let sourceText = ([blueprint.sourceTrigger, blueprint.reviewSummary] + blueprint.intelligenceDrivers)
                .joined(separator: " ")
                .uppercased()
            if sourceText.contains("TRANSCRIPT") { supportConfidence += 0.8 }
            if sourceText.contains("RESEARCH") { supportQuality += 0.6 }
            if sourceText.contains("CONSENSUS") { supportConfidence += 0.5 }
        }

        quality += min(supportQuality, 2.4)
        confidence += min(supportConfidence, 1.8)
        reward += min(supportReward, 0.9)

        return WealthProviderBias(
            qualityLift: quality,
            confidenceLift: confidence,
            rewardLift: reward,
            riskPenalty: risk
        )
    }

    var providerSources: [WealthProviderSource] {
        let researchSources = WealthExternalResearchKind.allCases.map { kind in
            makeResearchSource(kind)
        }

        return researchSources + [
            makeSource("Outcome", enabled: liveOutcomeLearningEnabled, detail: "Trade learning"),
            makeSource("Backtest", enabled: backtestEngineEnabled, detail: "Replay memory"),
            makeSource("Retraining", enabled: retrainingEnabled, detail: "Adaptive weights"),
            makeSource("Research Mesh", enabled: researchMeshEnabled, detail: "Cross-source consensus")
        ]
    }

    var activeProviderCount: Int {
        providerSources.filter { ["LIVE", "FRESH ONLINE", "CACHED", "NO LIVE CONFIG", "SYNTHETIC FALLBACK"].contains($0.status) }.count
    }

    var readinessLabel: String {
        if activeProviderCount >= 8 { return "FULL STACK" }
        if activeProviderCount >= 5 { return "STRONG STACK" }
        return "BASE STACK"
    }

    private func makeSource(_ name: String, enabled: Bool, detail: String) -> WealthProviderSource {
        WealthProviderSource(
            name: name,
            status: enabled ? "LIVE" : "OFF",
            detail: detail,
            tint: enabled ? WealthTheme.green : WealthTheme.grey
        )
    }

    private func makeResearchSource(_ kind: WealthExternalResearchKind) -> WealthProviderSource {
        let enabled = isEnabled(kind)
        let state = enabled ? (sourceStatesByKind[kind] ?? .syntheticFallback) : .off
        let updatedAt = sourceUpdatedAtByKind[kind].map(WealthFormat.clock) ?? "--:--"
        let providerMode = mode(for: kind)
        let detail = sourceDetailByKind[kind] ?? kind.detail
        let endpointMissing = enabled && endpoint(for: kind) == nil
        let statusDetail: String
        let statusLabel: String

        if !enabled {
            statusLabel = WealthExternalSignalState.off.rawValue
            statusDetail = detail
        } else if providerMode == .mockTest {
            statusLabel = "MOCK / TEST"
            statusDetail = "Sample provider responses in use."
        } else if endpointMissing && state == .syntheticFallback {
            statusLabel = "NO LIVE CONFIG"
            statusDetail = "No live provider endpoint is configured. Built-in fallback is active."
        } else {
            statusLabel = state.rawValue
            statusDetail = detail
        }

        return WealthProviderSource(
            name: kind.displayName,
            status: statusLabel,
            detail: "\(statusDetail) · \(updatedAt)",
            tint: providerMode == .mockTest ? WealthTheme.yellow : state.tint
        )
    }
}
