import SwiftUI

enum WealthMarketQualityTier: Int, CaseIterable {
    case top = 0
    case high = 1
    case medium = 2
    case low = 3

    var displayLabel: String {
        switch self {
        case .top: return "TIER A"
        case .high: return "TIER B"
        case .medium: return "TIER C"
        case .low: return "TIER D"
        }
    }
}

enum WealthExecutionReadiness: Equatable {
    case ready
    case blocked(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var reason: String? {
        switch self {
        case .ready:
            return nil
        case .blocked(let reason):
            return reason
        }
    }
}

extension Opportunity {
    private var marketRankingFreshnessLimit: TimeInterval { 24 * 60 * 60 }
    // Universe Update 8/4/2026: Extended from 5 minutes to 24 hours so that
    // ranked cards sitting in AI Live are not evicted by a promotion-refresh
    // staleness check. Cards persist until bought or rejected.
    private var downstreamPromotionRefreshLimit: TimeInterval { 24 * 60 * 60 }

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

    var hasIncompleteDisplayData: Bool {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        market.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        market.uppercased() == "UNKNOWN" ||
        price <= 0 ||
        aiScore <= 0 ||
        confidence <= 0
    }
    var clearsProfitGuard: Bool { expectedNetProfit > 0 }
    var meetsGreenBand: Bool { wealthHasGreenSignalBands(score: aiScore, confidence: confidence) }
    var hasNonNegativeCurrentPnL: Bool { liveNetProfit > 0 }
    var requiresLivePnLGreenGuard: Bool { false }
    var passesScoreGate: Bool { scoreTint != WealthTheme.red && confidenceTint != WealthTheme.red }
    var executionReadiness: WealthExecutionReadiness {
        if permission == .blocked {
            return .blocked("AI permission is blocked by a hard safety rule")
        }
        if permission != .go {
            return .blocked("AI permission is not clear yet")
        }
        if recommendedShares <= 0 {
            return .blocked("the position size is no longer valid")
        }
        if !trueCost.isFinite || trueCost <= 0 {
            return .blocked("the position size is no longer valid")
        }
        return .ready
    }
    var passesExecutionGate: Bool { executionReadiness.isReady }
    var passesWatchGate: Bool { decisionBias != .avoid }
    var isBlueWatchCandidate: Bool { cardHoldingBucket == .blue }
    var hasValidShieldProtection: Bool {
        WealthProtectionExitRules.hasValidShieldBoundary(
            entryPrice: effectiveEntryPrice,
            shares: recommendedShares,
            totalCost: trueCost,
            protection: WealthProtectionSettingsStore.shared
        )
    }
    var isExecutionEligible: Bool { executionReadiness.isReady }
    var isMarketExecutableCandidate: Bool {
        cardHoldingBucket == .green && executionReadiness.isReady
    }

    var cardSignalTint: Color {
        cardHoldingBucket.color
    }

    var cardSignalLabel: String {
        cardHoldingBucket.label
    }

    var sourceAgeText: String { WealthFormat.age(dataTimestamp) }
    var sourceAgeInterval: TimeInterval { max(0, Date().timeIntervalSince(dataTimestamp)) }
    var analysisAgeText: String { WealthFormat.age(analysisTimestamp) }
    var lastRefreshText: String { WealthFormat.clock(lastRefreshTimestamp) }
    var lastRefreshAgeInterval: TimeInterval { max(0, Date().timeIntervalSince(lastRefreshTimestamp)) }
    var hasFreshPromotionRefresh: Bool { lastRefreshAgeInterval <= downstreamPromotionRefreshLimit }
    var dataUpdateText: String { WealthFormat.clock(dataTimestamp) }
    var marketRegionLabel: String { WealthMarketLabels.region(for: market) }
    var marketDisplayLabel: String { WealthMarketLabels.display(for: market) }
    var nextTradingText: String { BrokerSessionClock.nextTradingText(for: market, brokerName: brokerName) }
    var ruleShieldVisible: Bool {
        decisionBias != .avoid && expectedNetReturnPercent > -WealthProtectionSettingsStore.shared.shieldPercent
    }
    var shieldTriggerPercent: Double {
        -max(0, WealthProtectionSettingsStore.shared.shieldPercent)
    }
    var manualShieldLabel: String {
        wealthPercentMoveText(shieldTriggerPercent)
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
    var profitLockLabel: String {
        wealthPercentMoveText(profitLockPercent)
    }
    var surgeStatusLabel: String {
        WealthProtectionSettingsStore.shared.surgeEnabled ? "ON" : "OFF"
    }
    var surgeOverrideLabel: String {
        WealthProtectionSettingsStore.shared.surgeEnabled
            ? wealthPercentMoveText(max(0, WealthProtectionSettingsStore.shared.surgeOverridePercent))
            : "OFF"
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
    var marketQualityTier: WealthMarketQualityTier { WealthEngineRefreshRanking.marketQualityTier(for: self) }
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

    var aiLiveIntelSummary: String {
        [
            sourceTrigger.trimmingCharacters(in: .whitespacesAndNewlines),
            intelligenceDriverText.trimmingCharacters(in: .whitespacesAndNewlines),
            intelligenceChannelText.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " | ")
    }

    var sourceFreshnessWarning: String? {
        let age = sourceAgeInterval
        switch age {
        case let seconds where seconds >= 7 * 24 * 60 * 60:
            return "Source intel is over a week old. Treat this as a weak buy until fresh data confirms it."
        case let seconds where seconds >= 24 * 60 * 60:
            return "Source intel is over 24 hours old. Market should not rank this until fresh data confirms it."
        case let seconds where seconds >= 3 * 24 * 60 * 60:
            return "Source intel is several days old. Fresh confirmation is needed before trusting the setup."
        default:
            return nil
        }
    }

    var marketSourceIsFreshEnough: Bool {
        sourceAgeInterval <= marketRankingFreshnessLimit
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
        isExecutionEligible && !sessionState.canTradeNow
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
        if cardHoldingBucket == .green {
            return "The card is green. Score, confidence, and target alignment are leading the setup, while execution safety checks remain separate downstream."
        }
        if isBlueWatchCandidate {
            return "The card stays on blue watch. Research is still useful, but the setup needs more brain-quality confirmation before moving toward Market."
        }
        if cardHoldingBucket == .purple {
            return "The card is purple because AI score and confidence are mixed. Purple is an intel state, not a P/L downgrade."
        }
        if cardHoldingBucket == .red {
            return "The card is red because the setup failed the checkpoint and is bad overall right now."
        }
        if !hasValidShieldProtection {
            return "Shield protection is unavailable right now. This affects post-buy protection, not whether the card can be reviewed for a buy."
        }
        return "AI is still monitoring this. The color shows the current setup state, while final execution checks stay separate."
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

    var monitorOnly: Bool { cardSignalTint != WealthTheme.green }

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
