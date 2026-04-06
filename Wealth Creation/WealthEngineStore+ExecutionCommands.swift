import Foundation

extension WealthEngineStore {
    static func executionStyle(
        decision: WealthDecisionBias,
        rotation: WealthRotationBias,
        mode: WealthAggressionMode,
        goals: WealthGoalVector,
        regime: WealthMarketRegime,
        confidence: Int,
        sessionOpen: Bool,
        advanced: WealthAdvancedSignalProfile
    ) -> WealthExecutionStyle {
        guard sessionOpen else { return .wait }
        guard decision == .buy else { return .wait }

        if rotation == .block {
            return .wait
        }

        if confidence >= 92 && advanced.qualityLift >= 8 && regime == .riskOn {
            return .strike
        }

        if mode == .aggressive || rotation == .rotate || goals.tradingPressure >= 0.28 {
            return .staged
        }

        if advanced.rewardLift >= 6 && advanced.riskPenalty <= 4 {
            return .stealth
        }

        return .staged
    }

    static func commandText(
        decision: WealthDecisionBias,
        permission: WealthPermissionState,
        rotation: WealthRotationBias,
        executionStyle: WealthExecutionStyle,
        symbol: String
    ) -> String {
        switch permission {
        case .blocked:
            return "BLOCK \(symbol)"
        case .wait:
            return "WAIT \(symbol)"
        case .go:
            if decision != .buy {
                return "WAIT \(symbol)"
            }

            switch executionStyle {
            case .strike:
                return rotation == .add ? "STRIKE BUY \(symbol)" : "BUY \(symbol)"
            case .staged:
                return "STAGE BUY \(symbol)"
            case .stealth:
                return "STEALTH BUY \(symbol)"
            case .wait:
                return "WAIT \(symbol)"
            }
        }
    }
}
