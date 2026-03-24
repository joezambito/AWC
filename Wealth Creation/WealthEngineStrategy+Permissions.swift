import SwiftUI

extension WealthEngineStore {
    static func permissionState(
        score: Int,
        confidence: Int,
        decision: WealthDecisionBias,
        buyingPower: Double,
        totalCost: Double,
        expectedNetProfit: Double,
        spreadBps: Double,
        slippageRisk: Double,
        risk: Double,
        symbol: String,
        market: String,
        killSwitch: Bool,
        sessionOpen: Bool,
        dataQuality: String,
        dataAge: Double,
        priceChangePercent: Double,
        rotation: WealthRotationBias,
        duplicateExposureCount: Int,
        trustState: WealthTrustState,
        advanced: WealthAdvancedSignalProfile,
        timeWindow: String,
        earningsEventRisk: Double,
        macroEventRisk: Double,
        rewardRiskRatio: Double,
        currentOpenPositions: Int,
        positionLimit: Int,
        maxSectorExposure: Int,
        dailyLossLocked: Bool,
        marketWideBrake: Bool,
        brokerCooldownActive: Bool
    ) -> WealthPermissionState {
        let toggles = WealthBrainToggleStore.shared
        let portfolio = WealthPortfolioStore.shared
        portfolio.clearExpiredBuyCooldown(for: symbol, market: market)

        let strongWatchSetup =
            score <= 20 &&
            confidence >= 80 &&
            decision != .avoid &&
            dataQuality != "STALE" &&
            trustState != .weak

        let slippageAdjustedNetProfit = expectedNetProfit - estimatedSlippageCost(
            totalCost: totalCost,
            spreadBps: spreadBps,
            slippageRisk: slippageRisk
        )

        if killSwitch || decision == .avoid || totalCost <= 0 { return .blocked }
        if dailyLossLocked || brokerCooldownActive { return .blocked }
        if portfolio.buyCooldown(for: symbol, market: market) != nil { return .blocked }
        if marketWideBrake { return .wait }
        if score > 39 { return .blocked }
        if score > 20 { return .wait }
        if currentOpenPositions >= positionLimit { return .wait }
        if duplicateExposureCount >= maxSectorExposure { return .blocked }
        if dataQuality == "STALE" || rotation == .block || trustState == .weak { return .blocked }
        if dataAge >= 86_400 { return .blocked }
        if rewardRiskRatio < 1.15 { return strongWatchSetup ? .wait : .blocked }
        if rewardRiskRatio < 1.55 { return .wait }

        if let spreadState = WealthAISafeguards.spreadSpikeState(spreadBps: spreadBps, slippageRisk: slippageRisk) {
            return spreadState
        }

        if let volatilityState = WealthAISafeguards.volatilityShockState(priceChangePercent: priceChangePercent, timeWindow: timeWindow),
           !allowsExceptionalShockOverride(confidence: confidence, risk: risk, advanced: advanced) {
            return volatilityState
        }

        if slippageAdjustedNetProfit < 24 { return strongWatchSetup ? .wait : .blocked }
        if expectedNetProfit < 28 { return .wait }
        if dataQuality != "FRESH" { return .wait }
        if confidence < 80 { return .wait }
        if dataQuality == "AGING" || dataAge >= 21_600 { return .wait }
        if priceChangePercent <= -8 && !allowsExceptionalRecovery(priceChangePercent: priceChangePercent, confidence: confidence, advanced: advanced) {
            return .wait
        }
        if eventRiskBlocks(
            score: score,
            confidence: confidence,
            dataQuality: dataQuality,
            advanced: advanced,
            earningsEventRisk: earningsEventRisk,
            macroEventRisk: macroEventRisk
        ) {
            return .blocked
        }
        if earningsEventRisk >= 55 || macroEventRisk >= 60 { return .wait }
        if slippageRisk >= 58 || spreadBps >= 45 { return .wait }
        if trustState == .caution { return .wait }
        if duplicateExposureCount >= 2 && rotation == .add { return .wait }

        if toggles.isEnabled(title: "Execution Safety Layer"),
           (advanced.anomalyState == "ANOMALY HIGH" || advanced.executionState == "EXECUTION RISK") {
            return .blocked
        }

        if toggles.isEnabled(title: "Tail-Risk Overrides"),
           timeWindow == "HOURS",
           advanced.eventState == "EVENT SOFT",
           advanced.anomalyState != "STABLE" {
            return .wait
        }

        if totalCost > buyingPower { return .wait }
        if !sessionOpen { return .go }
        return .go
    }

    private static func allowsExceptionalShockOverride(
        confidence: Int,
        risk: Double,
        advanced: WealthAdvancedSignalProfile
    ) -> Bool {
        confidence >= 95 &&
        risk <= 22 &&
        advanced.executionState == "EXECUTION CLEAN" &&
        advanced.smartMoneyState.contains("STRONG")
    }

    private static func allowsExceptionalRecovery(
        priceChangePercent: Double,
        confidence: Int,
        advanced: WealthAdvancedSignalProfile
    ) -> Bool {
        priceChangePercent <= -10 &&
        confidence >= 85 &&
        (advanced.patternState.contains("STRONG") ||
         advanced.smartMoneyState.contains("STRONG") ||
         advanced.eventState.contains("STRONG"))
    }

    private static func eventRiskBlocks(
        score: Int,
        confidence: Int,
        dataQuality: String,
        advanced: WealthAdvancedSignalProfile,
        earningsEventRisk: Double,
        macroEventRisk: Double
    ) -> Bool {
        guard earningsEventRisk >= 72 || macroEventRisk >= 78 else { return false }

        let exceptionalEventOverride =
            score <= 8 &&
            confidence >= 94 &&
            dataQuality == "FRESH" &&
            advanced.smartMoneyState.contains("STRONG") &&
            advanced.executionState == "EXECUTION CLEAN"

        return !exceptionalEventOverride
    }

    private static func estimatedSlippageCost(totalCost: Double, spreadBps: Double, slippageRisk: Double) -> Double {
        let spreadComponent = max(0.0015, spreadBps / 10_000)
        let slippageComponent = max(0.001, min(0.02, slippageRisk / 5_000))
        return totalCost * (spreadComponent + slippageComponent)
    }
}
