import Foundation

extension WealthEngineDirectiveText {
    static func makeBrainSnapshot(
        goals: WealthGoalVector,
        regime: WealthMarketRegime,
        mode: WealthAggressionMode,
        hunger: WealthHungerMode,
        hottest: Opportunity?
    ) -> WealthBrainSnapshot {
        let advanced = hottest?.advancedSignal ?? .neutral
        let toggles = WealthBrainToggleStore.shared
        let summary: String
        let capitalDiscipline: String
        let modelReadiness: String
        let dataReadiness: String

        switch mode {
        case .aggressive:
            summary = "The AI is leaning harder into short-term setups while tracking \(advanced.trendState.lowercased()) and \(advanced.smartMoneyState.lowercased()). Campaign pressure is active."
        case .moderate:
            summary = "The AI stays selective while monitoring \(advanced.momentumState.lowercased()) and \(advanced.eventState.lowercased()). Targets are guiding the ranking path."
        case .protect:
            summary = "The AI protects gains, respects \(advanced.anomalyState.lowercased()), and avoids oversizing."
        }

        if toggles.isEnabled(title: "Portfolio Optimizer") && toggles.isEnabled(title: "Exposure Balancer") {
            capitalDiscipline = "OPTIMIZED SIZE"
        } else if toggles.isEnabled(title: "Capital Rotation Planner") {
            capitalDiscipline = "ROTATION SIZE"
        } else {
            capitalDiscipline = "DYNAMIC SIZE"
        }

        if hottest == nil {
            modelReadiness = "DEMO READY"
        } else if toggles.isEnabled(title: "Model Registry") && toggles.isEnabled(title: "Explainability Layer") {
            modelReadiness = "TRACKED MODEL"
        } else {
            modelReadiness = "LIVE MODEL"
        }

        if let hottest {
            let freshness = hottest.dataQualityLabel.uppercased()
            if toggles.isEnabled(title: "Data Infrastructure") && toggles.isEnabled(title: "Historical Feature Store") {
                dataReadiness = "\(freshness) STACK"
            } else {
                dataReadiness = freshness
            }
        } else {
            dataReadiness = "WAITING DATA"
        }

        return WealthBrainSnapshot(
            mode: mode,
            hunger: hunger,
            regime: regime,
            targetPressure: WealthEngineStore.targetPressureLabel(goals),
            targetPressureValue: goals.tradingPressure,
            targetDriver: goals.dominantTarget.capitalized,
            capitalDiscipline: capitalDiscipline,
            summary: summary,
            hottestSymbol: hottest?.symbol ?? "--",
            hottestDecision: hottest?.decisionBias.rawValue ?? "WAIT",
            hottestCommand: hottest?.commandText ?? "WAIT FOR EDGE",
            rotationSignal: hottest?.rotationBias.rawValue ?? "NO ROTATION",
            trustSignal: hottest?.trustState.rawValue ?? "TRUST FIRST",
            trendSignal: advanced.trendState,
            momentumSignal: advanced.momentumState,
            patternSignal: advanced.patternState,
            smartMoneySignal: advanced.smartMoneyState,
            eventSignal: advanced.eventState,
            anomalySignal: advanced.anomalyState,
            modelReadiness: modelReadiness,
            dataReadiness: dataReadiness
        )
    }
}
