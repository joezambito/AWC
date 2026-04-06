import Foundation

enum WealthBuyDecisionRules {
    static func decisionBias(
        score: Int,
        confidence: Int,
        safety _: Int,
        expectedProfit: Double,
        timeWindow: String,
        dataQuality: String,
        priceChangePercent: Double,
        advanced: WealthAdvancedSignalProfile
    ) -> WealthDecisionBias {
        let exceptionalRecovery =
            priceChangePercent <= -10 &&
            confidence >= 85 &&
            (
                advanced.patternState.contains("STRONG") ||
                advanced.smartMoneyState.contains("STRONG") ||
                advanced.eventState.contains("STRONG")
            )

        let buyReadyNow =
            wealthBuyReady(score: score, confidence: confidence) &&
            expectedProfit >= 28 &&
            dataQuality == "FRESH" &&
            timeWindow != "WEEKS" &&
            (priceChangePercent > -6 || exceptionalRecovery)

        if buyReadyNow {
            return .buy
        }

        if score <= 39 && confidence >= 60 {
            return .buy
        }

        return .avoid
    }

    static func warningReason(
        blueprint: OpportunityBlueprint,
        score: Int,
        confidence: Int,
        regime: WealthMarketRegime
    ) -> String {
        let toggles = WealthBrainToggleStore.shared

        if score >= 60 {
            return "Avoid bias. The setup is too weak for fast short-term money."
        }

        if confidence < 60 {
            return "Hold back. The AI is not confident enough yet."
        }

        if toggles.isEnabled(title: "Liquidity / Slippage Controls") && blueprint.capitalFitLabel.uppercased().contains("POOR") {
            return "Tradeability is weak, so the AI is guarding against thin fills and slippage."
        }

        if regime == .defensive && blueprint.timeWindow == "HOURS" {
            return "Regime is defensive, so fast entries need extra care."
        }

        if toggles.isEnabled(title: "Rollback / Safe Revert") {
            return "Capital size stays dynamic and the AI can step back quickly if the setup degrades."
        }

        return "Capital size stays dynamic so one trade does not overload the account."
    }
}
