import Foundation
import Combine

@MainActor
final class WealthBrainStore: ObservableObject {
    static let shared = WealthBrainStore()

    @Published private(set) var featureSnapshots: [WealthBrainFeatureSnapshot] = []
    @Published private(set) var modelState = WealthBrainModelState.placeholder
    @Published private(set) var lastLearningSummary = "Brain memory waiting for the next cycle."

    var symbolStrength: [String: Double] = [:]
    var sectorStrength: [String: Double] = [:]

    private init() {}

    func ingest(
        opportunities: [Opportunity],
        stage: Int,
        stageTotal: Int,
        cycleComplete: Bool,
        lastRefresh: Date?
    ) {
        let timestamp = lastRefresh ?? .now
        featureSnapshots = Array(opportunities.prefix(8)).map { opportunity in
            WealthBrainFeatureSnapshot(
                symbol: opportunity.symbol,
                rank: opportunity.rank,
                trend: opportunity.advancedSignal.trendState,
                momentum: opportunity.advancedSignal.momentumState,
                pattern: opportunity.advancedSignal.patternState,
                smartMoney: opportunity.advancedSignal.smartMoneyState,
                event: opportunity.advancedSignal.eventState,
                execution: opportunity.advancedSignal.executionState,
                portfolioFit: opportunity.advancedSignal.portfolioState,
                anomaly: opportunity.advancedSignal.anomalyState,
                qualityLift: opportunity.advancedSignal.qualityLift,
                confidenceLift: opportunity.advancedSignal.confidenceLift,
                rewardLift: opportunity.advancedSignal.rewardLift,
                riskPenalty: opportunity.advancedSignal.riskPenalty,
                timestamp: timestamp
            )
        }

        let readiness = cycleComplete ? "UP TO DATE" : "LEARNING \(stage)/\(stageTotal)"
        let anomalyWatch = featureSnapshots.first(where: { $0.anomaly != "STABLE" })?.anomaly ?? "STABLE"
        let dataReadiness: String = {
            guard let top = opportunities.first else { return "NO DATA" }
            switch top.dataQualityLabel.uppercased() {
            case "FRESH":
                return "LIVE FRESH"
            case "AGING":
                return "AGING"
            case "STALE":
                return "STALE"
            default:
                return "MIXED"
            }
        }()

        modelState = WealthBrainModelState(
            modelVersion: "BRAIN-V2",
            featureSnapshots: featureSnapshots.count,
            activatedBrainItems: WealthBrainToggleStore.shared.activeRuntimeCount,
            topSymbol: opportunities.first?.symbol ?? "--",
            computeMode: cycleComplete ? computeModeLabel : "STAGED",
            trainingState: opportunities.isEmpty ? "WAITING" : trainingStateLabel,
            governanceState: governanceStateLabel,
            readiness: readinessLabel(base: readiness),
            anomalyWatch: anomalyWatch,
            dataReadiness: dataReadiness
        )

        if let top = opportunities.first {
            lastLearningSummary = "\(top.symbol) leads with \(top.advancedSignal.trendState.lowercased()), \(top.advancedSignal.smartMoneyState.lowercased()), and \(top.advancedSignal.executionState.lowercased()). \(WealthBrainToggleStore.shared.activeRuntimeCount) brain items are active in \(WealthBrainToggleStore.shared.runtimeMode.rawValue.lowercased()) mode with \(modelState.governanceState.lowercased())."
        } else {
            lastLearningSummary = "Brain memory waiting for the next cycle."
        }

        learn(from: opportunities, holdings: WealthPortfolioStore.shared.holdings)
    }
}
