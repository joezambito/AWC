import SwiftUI

extension WealthEngineStore {
    static func dynamicAllocationPercent(
        score: Int,
        confidence: Int,
        decision: WealthDecisionBias,
        goals: WealthGoalVector,
        regime: WealthMarketRegime,
        holdings: [Holding],
        sector: String,
        advanced: WealthAdvancedSignalProfile
    ) -> Int {
        guard decision != .avoid else { return 0 }

        let toggles = WealthBrainToggleStore.shared
        let sectorExposure = holdings.filter { $0.sector == sector }.count

        var percent = 18
        percent += scoreAllocationBoost(score)
        percent += confidenceAllocationBoost(confidence)
        percent += goals.tradingPressure >= 0.28 ? 2 : 0
        percent += regimeAllocationAdjustment(regime)

        if toggles.isEnabled(title: "Portfolio Optimizer"), advanced.executionState == "EXECUTION CLEAN" {
            percent += 4
        }
        if toggles.isEnabled(title: "Exposure Balancer"), advanced.portfolioState == "PORTFOLIO FIT STRONG" {
            percent += 3
        }
        if toggles.isEnabled(title: "Portfolio Heat Map"), advanced.anomalyState != "STABLE" {
            percent -= 6
        }

        percent -= sectorExposure * 8
        if toggles.isEnabled(title: "Exposure Balancer"), sectorExposure == 0 {
            percent += 2
        }

        return min(65, max(8, percent))
    }

    private static func scoreAllocationBoost(_ score: Int) -> Int {
        if score <= 12 { return 16 }
        if score <= 25 { return 10 }
        if score <= 39 { return 4 }
        return 0
    }

    private static func confidenceAllocationBoost(_ confidence: Int) -> Int {
        if confidence >= 85 { return 10 }
        if confidence >= 70 { return 5 }
        return 0
    }

    private static func regimeAllocationAdjustment(_ regime: WealthMarketRegime) -> Int {
        switch regime {
        case .riskOn:
            return 6
        case .defensive:
            return -8
        default:
            return 0
        }
    }
}
