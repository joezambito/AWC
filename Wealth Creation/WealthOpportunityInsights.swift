import Foundation
import SwiftUI

extension Opportunity {
    var buyBlockReason: String {
        if isGreenBuyReady {
            return "Buy ready. AI score, confidence, and net profit are all clear."
        }
        if isBlueWatchCandidate {
            return "AI score and confidence are green, but net profit is still below costs, so AI keeps this on blue watch."
        }
        if warningReason.localizedCaseInsensitiveContains("cooldown") {
            return warningReason
        }
        if confidence < 80 {
            return "Confidence is not green yet, so AI keeps this on monitor only."
        }
        if aiScore > 20 {
            return "AI score is not green yet, so AI keeps this on monitor only."
        }
        switch permission {
        case .blocked:
            return warningReason.isEmpty ? "AI blocked this setup under the current rules." : warningReason
        case .wait:
            return warningReason.isEmpty ? "AI is waiting for cleaner confirmation before buying." : warningReason
        case .go:
            return "AI is monitoring for a stronger confirmation pass."
        }
    }

    var staleDataWarning: String? {
        switch dataQualityLabel.uppercased() {
        case "STALE":
            return "Data is stale. AI will not buy until fresh data confirms the setup."
        case "AGING":
            return "Data is aging. AI is monitoring for a fresh update before trusting the entry."
        default:
            return nil
        }
    }

    var eventRiskWarning: String? {
        if earningsEventRisk >= 55 && macroEventRisk >= 60 {
            return "Event risk is high. Earnings and macro pressure are both elevated, so AI is staying patient."
        }
        if earningsEventRisk >= 55 {
            return "Earnings risk is elevated. AI wants cleaner post-event confirmation before buying."
        }
        if macroEventRisk >= 60 {
            return "Macro risk is elevated. AI is waiting for the wider market pressure to settle."
        }
        return nil
    }

    var liquidityWarning: String? {
        let fit = capitalFitLabel.uppercased()
        if fit.contains("POOR") {
            return "Liquidity is thin or slippage risk is high. AI will avoid forcing size into this setup."
        }
        if fit.contains("HEAVY") {
            return "Position sizing is heavy for current capital, so AI may stage this entry instead of striking all at once."
        }
        return nil
    }

    var scoreUpgradePath: String {
        var needs: [String] = []

        if warningReason.localizedCaseInsensitiveContains("cooldown") {
            needs.append("cooldown to expire")
        }
        if !clearsProfitGuard {
            needs.append("net profit back above costs")
        }
        if aiScore > 20 {
            needs.append("AI score back into green")
        }
        if confidence < 80 {
            needs.append("confidence back into green")
        }
        if staleDataWarning != nil {
            needs.append("fresh data")
        }
        if eventRiskWarning != nil {
            needs.append("lower event risk")
        }
        if liquidityWarning != nil && tradeabilityLabel != "TRADEABLE" {
            needs.append("cleaner liquidity")
        }

        if needs.isEmpty {
            return "The setup is close. AI is waiting for the final permission checks to clear."
        }

        return "Needs " + needs.joined(separator: ", ") + "."
    }

    var tradeabilityLabel: String {
        if capitalFitLabel.uppercased().contains("POOR") {
            return "THIN / SLIPPAGE RISK"
        }
        if capitalFitLabel.uppercased().contains("HEAVY") {
            return "HEAVY SIZE"
        }
        return "TRADEABLE"
    }

    var tradeabilityTint: Color {
        if capitalFitLabel.uppercased().contains("POOR") {
            return WealthTheme.orange
        }
        if capitalFitLabel.uppercased().contains("HEAVY") {
            return WealthTheme.gold
        }
        return WealthTheme.green
    }

    var sessionState: MarketSessionState {
        BrokerSessionClock.state(for: market, brokerName: brokerName)
    }

    var recoverySetupLabel: String? {
        guard decisionBias == .buy, priceChangePercent <= -10 else { return nil }

        let decisionText = [
            reviewSummary,
            sourceSummary,
            buyReason,
            sourceTrigger,
            advancedSignal.trendState,
            advancedSignal.patternState,
            advancedSignal.eventState
        ]
        .joined(separator: " ")
        .uppercased()

        if decisionText.contains("OVERSOLD") || decisionText.contains("REBOUND") {
            return "OVERSOLD REBOUND"
        }
        if decisionText.contains("RECOVERY") || decisionText.contains("TURNAROUND") || decisionText.contains("BASE") {
            return "RECOVERY SETUP"
        }
        if decisionText.contains("CATALYST") || decisionText.contains("GUIDANCE") || decisionText.contains("EARNINGS") || decisionText.contains("EVENT") {
            return "CATALYST REVERSAL"
        }
        if advancedSignal.patternState.contains("PATTERN STRONG") || advancedSignal.trendState.contains("TREND EARLY") {
            return "EARLY REVERSAL"
        }

        return "REBOUND WATCH"
    }

    var recoverySetupTint: Color {
        guard recoverySetupLabel != nil else { return WealthTheme.white }
        if priceChangePercent <= -25 {
            return WealthTheme.gold
        }
        return WealthTheme.cyan
    }
}
