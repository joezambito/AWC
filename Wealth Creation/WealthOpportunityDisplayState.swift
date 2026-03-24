import SwiftUI

extension Opportunity {
    var effectiveEntryPrice: Double { submittedPrice > 0 ? submittedPrice : price }
    var entrySubtotalCost: Double { Double(recommendedShares) * effectiveEntryPrice }
    var subtotalCost: Double { Double(recommendedShares) * price }
    var trueCost: Double { entrySubtotalCost + brokerFee }
    var scoreStyle: ScoreStyle { WealthScoreMap.style(for: aiScore, rank: rank) }
    var status: String { scoreStyle.state.rawValue }
    var scoreTint: Color { wealthScoreTint(aiScore) }
    var confidenceTint: Color { wealthConfidenceTint(confidence) }

    var estimatedGrossExitValue: Double { max(0, entrySubtotalCost + expectedProfit) }
    var sellFee: Double { WealthScoringEngine.feeEstimate(for: estimatedGrossExitValue) }
    var roundTripFees: Double { brokerFee + sellFee }
    var estimatedNetExitValue: Double { max(0, estimatedGrossExitValue - sellFee) }
    var expectedNetProfit: Double { expectedProfit - roundTripFees }
    var liveGrossExitValue: Double { max(0, subtotalCost) }
    var liveSellFee: Double { WealthScoringEngine.feeEstimate(for: liveGrossExitValue) }
    var liveNetExitValue: Double { max(0, liveGrossExitValue - liveSellFee) }
    var liveNetProfit: Double { liveNetExitValue - trueCost }
    var liveMovePercent: Double { priceChangePercent }
    var liveNetReturnPercent: Double {
        guard trueCost > 0 else { return 0 }
        return (liveNetProfit / trueCost) * 100
    }
    var expectedNetReturnPercent: Double {
        guard trueCost > 0 else { return 0 }
        return (expectedNetProfit / trueCost) * 100
    }
    var projectedMovePercent: Double { expectedNetReturnPercent }
    var rewardMultiple: Double { expectedNetProfit / max(trueCost, 1) }

    var clearsProfitGuard: Bool { expectedNetProfit > 0 }
    var passesScoreGate: Bool { wealthBuyReady(score: aiScore, confidence: confidence) }
    var passesExecutionGate: Bool { permission == .go }
    var passesWatchGate: Bool { permission != .blocked }
    var isBlueWatchCandidate: Bool { passesScoreGate && passesWatchGate && !clearsProfitGuard }
    var isGreenBuyReady: Bool { passesScoreGate && passesExecutionGate && clearsProfitGuard }

    var cardSignalTint: Color {
        if isGreenBuyReady { return WealthTheme.green }
        if isBlueWatchCandidate { return WealthTheme.blue }
        return wealthCardSignalTint(score: aiScore, confidence: confidence)
    }

    var cardSignalLabel: String {
        if isGreenBuyReady { return "GREEN" }
        if isBlueWatchCandidate { return "WATCH" }
        return cardSignalTint == WealthTheme.purple ? "MIXED" : "LOCKED"
    }

    var sourceAgeText: String { WealthFormat.age(dataTimestamp) }
    var analysisAgeText: String { WealthFormat.age(analysisTimestamp) }
    var lastRefreshText: String { WealthFormat.clock(lastRefreshTimestamp) }
    var dataUpdateText: String { WealthFormat.clock(dataTimestamp) }
    var marketRegionLabel: String { WealthMarketLabels.region(for: market) }
    var marketDisplayLabel: String { WealthMarketLabels.display(for: market) }
    var nextTradingText: String { BrokerSessionClock.nextTradingText(for: market, brokerName: brokerName) }
    var ruleShieldVisible: Bool {
        permission != .blocked && expectedNetReturnPercent > -WealthProtectionSettingsStore.shared.shieldPercent
    }
    var shieldTriggerPercent: Double {
        -max(0, WealthProtectionSettingsStore.shared.shieldPercent)
    }
    var fixedBufferTriggerPercent: Double { -5 }
    var fixedBufferExitPrice: Double {
        targetExitPrice(forNetReturnPercent: fixedBufferTriggerPercent)
    }
    var fixedBufferExitSummary: String {
        "\(WealthFormat.money(fixedBufferExitPrice)) (\(wealthPercentMoveText(fixedBufferTriggerPercent)))"
    }
    var shieldExitPrice: Double {
        targetExitPrice(forNetReturnPercent: shieldTriggerPercent)
    }
    var shieldExitSummary: String {
        "\(WealthFormat.money(shieldExitPrice)) (\(wealthPercentMoveText(shieldTriggerPercent)))"
    }
    var shieldExitNetValue: Double {
        targetExitNetValue(forPrice: shieldExitPrice)
    }
    var profitLockPercent: Double {
        max(0, WealthProtectionSettingsStore.shared.profitTargetValue)
    }
    var surgeTriggerPercent: Double {
        let protection = WealthProtectionSettingsStore.shared
        if protection.surgeEnabled {
            return profitLockPercent + max(0, protection.surgeOverridePercent)
        }
        return profitLockPercent
    }
    var surgeExitPrice: Double {
        targetExitPrice(forNetReturnPercent: surgeTriggerPercent)
    }
    var surgeExitNetValue: Double {
        targetExitNetValue(forPrice: surgeExitPrice)
    }
    var aiBandLabel: String { "\(rank)" }

    var predictedHoldText: String {
        let cleaned = timeToTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? timeWindow : cleaned
    }

    var intelligenceDriverText: String {
        intelligenceDrivers.isEmpty ? "No extra intel" : intelligenceDrivers.joined(separator: " · ")
    }

    var intelligenceChannelText: String {
        intelligenceChannels.isEmpty ? dataOrigin : intelligenceChannels.joined(separator: " · ")
    }

    var optionsFlowLabel: String { feedStrengthLabel(optionsFlowStrength) }
    var darkPoolLabel: String { feedStrengthLabel(darkPoolStrength) }
    var insiderLabel: String { feedStrengthLabel(insiderStrength) }
    var filingLabel: String { feedStrengthLabel(filingStrength) }
    var earningsRiskLabel: String { riskStrengthLabel(earningsEventRisk) }
    var macroRiskLabel: String { riskStrengthLabel(macroEventRisk) }

    var reservedCapital: Double {
        switch orderState {
        case .submitted, .pending, .partial:
            return trueCost
        case .ready:
            return canQueueForOpen ? trueCost : 0
        case .filled:
            return 0
        }
    }

    var canQueueForOpen: Bool {
        isGreenBuyReady && !sessionState.canTradeNow && recommendedShares > 0
    }

    var aiRiskStance: String {
        let edgeStrength = Double(confidence + safety) - Double(aiScore)
        if scoreStyle.tier == .weak || rewardMultiple < 0.02 || edgeStrength < 85 { return "DEFENSIVE" }
        if expectedNetProfit >= 8 && rewardMultiple >= 0.035 && edgeStrength >= 130 { return "AGGRESSIVE" }
        return "ACTIVE"
    }

    var scoreBandText: String { "AI SCORE: \(wealthScoreBandGuideRows().joined(separator: ", ").lowercased())." }
    var confidenceBandText: String { "CONFIDENCE: \(wealthConfidenceBandGuideRows().joined(separator: ", ").lowercased())." }

    var readinessSummary: String {
        if isGreenBuyReady {
            return "AI can buy this now. AI score and confidence are both green, the trade gate is open, and projected net profit is above costs."
        }
        if isBlueWatchCandidate {
            return "AI is watching this closely. AI score and confidence are green, but the projected trade is still below net profit after costs."
        }
        return "AI is still monitoring this. The card stays live, but it will not buy until the AI score, confidence, and protection checks line up."
    }

    var scoreDriftText: String {
        guard let previousAiScore else { return "No earlier AI score yet." }
        if aiScore < previousAiScore { return "AI score improved from \(previousAiScore) to \(aiScore)." }
        if aiScore > previousAiScore { return "AI score weakened from \(previousAiScore) to \(aiScore)." }
        return "AI score is holding at \(aiScore)."
    }

    var confidenceDriftText: String {
        guard let previousConfidence else { return "No earlier confidence read yet." }
        if confidence > previousConfidence { return "Confidence improved from \(previousConfidence)% to \(confidence)%." }
        if confidence < previousConfidence { return "Confidence fell from \(previousConfidence)% to \(confidence)%." }
        return "Confidence is holding at \(confidence)%."
    }

    var researchStackText: String {
        [
            "SOURCE · \(sourceSummary)",
            "REVIEW · \(reviewSummary)",
            "DRIVERS · \(intelligenceDriverText)",
            "CHANNELS · \(intelligenceChannelText)"
        ]
        .joined(separator: "\n")
    }

    var blockerSummary: String {
        let parts = ([buyBlockReason] + [staleDataWarning, eventRiskWarning, liquidityWarning].compactMap { $0 })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.isEmpty {
            return "No active blockers. AI is judging live price action, projected net profit, timing, and protection checks."
        }

        return parts.joined(separator: " ")
    }

    var monitorOnly: Bool { !isGreenBuyReady }

    private func targetExitPrice(forNetReturnPercent targetReturnPercent: Double) -> Double {
        guard recommendedShares > 0 else { return 0 }

        let targetNetValue = max(0, trueCost * (1 + (targetReturnPercent / 100)))
        let percentageGrossValue = targetNetValue / (1 - 0.00047)
        let flatFeeGrossValue = targetNetValue + 0.50
        let grossValue = max(percentageGrossValue, flatFeeGrossValue)

        return max(0, grossValue / Double(recommendedShares))
    }

    private func targetExitNetValue(forPrice price: Double) -> Double {
        guard recommendedShares > 0 else { return 0 }
        let grossValue = Double(recommendedShares) * price
        let fee = max(0.50, grossValue * 0.00047)
        return max(0, grossValue - fee)
    }

    private func feedStrengthLabel(_ value: Double) -> String {
        switch value {
        case 80...: return "STRONG"
        case 60..<80: return "ACTIVE"
        case 35..<60: return "WATCH"
        default: return "LIGHT"
        }
    }

    private func riskStrengthLabel(_ value: Double) -> String {
        switch value {
        case 70...: return "HIGH"
        case 40..<70: return "WATCH"
        case 15..<40: return "LOW"
        default: return "CLEAR"
        }
    }
}
