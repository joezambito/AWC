import Foundation

struct Holding: Identifiable, Hashable {
    var id: String { "\(symbol.uppercased())-\(market.uppercased())" }

    let symbol: String
    let market: String
    let sector: String
    var shares: Int
    var averagePrice: Double
    var currentPrice: Double
    var aiScore: Int
    var aiBand: Int
    var confidence: Int
    var safety: Int
    var prospect: String
    var timeWindow: String
    var riskLabel: String
    var holdLabel: String
    var safeKeepLabel: String
    var lockLabel: String
    var sourceTrigger: String
    var dataOrigin: String
    var reviewSummary: String
    var researchSummary: String
    var analysisTimestamp: Date
    var dataTimestamp: Date
    var lastRefreshTimestamp: Date = .now
    var filledAt: Date?
    var orderIntent: HoldingOrderIntent
    var orderState: OrderExecutionState
    var pendingShares: Int
    var submittedExitPrice: Double?
    var orderSubmittedAt: Date?

    var effectiveCurrentPrice: Double {
        WealthHoldingLivePriceResolver.resolvedCurrentPrice(
            currentPrice: currentPrice,
            livePrice: 0,
            averagePrice: averagePrice
        )
    }
    var marketValue: Double { Double(shares) * effectiveCurrentPrice }
    var costBasis: Double { Double(shares) * averagePrice }
    var buyFee: Double { max(1.62, costBasis * 0.00709) }
    var buyTotalCost: Double { costBasis + buyFee }
    var estimatedSellFee: Double { max(0.50, marketValue * 0.00047) }
    var netLiquidationValue: Double { max(0, marketValue - estimatedSellFee) }
    var unrealizedPnL: Double { netPnL }
    var netPnL: Double { netLiquidationValue - buyTotalCost }
    var liveMovePercent: Double {
        guard averagePrice > 0 else { return 0 }
        return ((effectiveCurrentPrice - averagePrice) / averagePrice) * 100
    }
    var percentChange: Double { liveMovePercent }
    var netReturnPercent: Double {
        guard buyTotalCost > 0 else { return 0 }
        return (netPnL / buyTotalCost) * 100
    }

    var availableShares: Int { max(0, shares - pendingShares) }
    var pendingExitPrice: Double { submittedExitPrice ?? effectiveCurrentPrice }
    var pendingGrossValue: Double { Double(pendingShares) * pendingExitPrice }
    var pendingSellFee: Double { pendingShares > 0 ? max(0.50, pendingGrossValue * 0.00047) : 0 }
    var pendingNetValue: Double { max(0, pendingGrossValue - pendingSellFee) }
    var pendingCostBasis: Double {
        guard shares > 0 else { return 0 }
        return buyTotalCost * (Double(pendingShares) / Double(shares))
    }
    var pendingNetPnL: Double { pendingNetValue - pendingCostBasis }
    var pendingNetReturnPercent: Double {
        guard pendingCostBasis > 0 else { return 0 }
        return (pendingNetPnL / pendingCostBasis) * 100
    }

    var pendingAgeText: String? {
        guard let orderSubmittedAt else { return nil }
        return WealthFormat.age(orderSubmittedAt)
    }

    var scoreStyle: ScoreStyle { WealthScoreMap.style(for: aiScore) }
    var lastRefreshText: String { WealthFormat.clock(lastRefreshTimestamp) }
    var dataUpdateText: String { WealthFormat.clock(dataTimestamp) }
    var marketRegionLabel: String { WealthMarketLabels.region(for: market) }
    var marketDisplayLabel: String { WealthMarketLabels.display(for: market) }
    var nextTradingText: String {
        BrokerSessionClock.nextTradingText(for: market, brokerName: WealthBrokerStore.shared.selectedBroker.name)
    }
    var manualShieldEnabled: Bool {
        WealthProtectionSettingsStore.shared.shieldPercent > 0
    }
    var manualShieldLabel: String {
        "\(Int(max(0, WealthProtectionSettingsStore.shared.shieldPercent)))%"
    }
    var ruleShieldVisible: Bool {
        netReturnPercent > -WealthProtectionSettingsStore.shared.shieldPercent
    }
    var fixedBufferTriggerPercent: Double { -5 }
    var fixedBufferExitPrice: Double {
        exitPrice(forNetReturnPercent: fixedBufferTriggerPercent)
    }
    var fixedBufferExitSummary: String {
        "\(WealthFormat.money(fixedBufferExitPrice)) (\(wealthPercentMoveText(fixedBufferTriggerPercent)))"
    }
    var shieldTriggerPercent: Double {
        -max(0, WealthProtectionSettingsStore.shared.shieldPercent)
    }
    var shieldTriggered: Bool {
        netReturnPercent <= shieldTriggerPercent
    }
    var shieldExitPrice: Double {
        exitPrice(forNetReturnPercent: shieldTriggerPercent)
    }
    var shieldExitSummary: String {
        "\(WealthFormat.money(shieldExitPrice)) (\(wealthPercentMoveText(shieldTriggerPercent)))"
    }
    var shieldExitNetValue: Double {
        exitNetValue(forPrice: shieldExitPrice)
    }
    var profitLockPercent: Double {
        max(0, WealthProtectionSettingsStore.shared.profitTargetValue)
    }
    var surgeStatusLabel: String {
        WealthProtectionSettingsStore.shared.surgeEnabled ? "ON" : "OFF"
    }
    var surgeOverrideLabel: String {
        WealthProtectionSettingsStore.shared.surgeEnabled
            ? "+\(Int(max(0, WealthProtectionSettingsStore.shared.surgeOverridePercent)))%"
            : "OFF"
    }
    var surgeTriggerPercent: Double {
        let protection = WealthProtectionSettingsStore.shared
        if protection.surgeEnabled {
            return profitLockPercent + max(0, protection.surgeOverridePercent)
        }
        return profitLockPercent
    }
    var surgeTriggered: Bool {
        netReturnPercent >= surgeTriggerPercent
    }
    var surgeExitPrice: Double {
        exitPrice(forNetReturnPercent: surgeTriggerPercent)
    }
    var surgeExitSummary: String {
        "\(WealthFormat.money(surgeExitPrice)) (\(wealthPercentMoveText(surgeTriggerPercent)))"
    }
    var surgeExitNetValue: Double {
        exitNetValue(forPrice: surgeExitPrice)
    }
    var filledAtText: String { WealthFormat.dayClock(filledAt) }

    var aiCommentary: String {
        let lead = primaryCommentaryText
        let move = netReturnPercent >= 0
            ? "Net return is up \(WealthFormat.percent(netReturnPercent))."
            : "Net return is down \(WealthFormat.percent(netReturnPercent))."
        return "\(lead) \(move)"
    }

    var riskMatrixText: String {
        [
            "RISK \(riskLabel.uppercased())",
            "HOLD \(holdLabel.uppercased())",
            "TARGET \(safeKeepLabel.uppercased())",
            "LOCK \(lockLabel.uppercased())"
        ]
        .joined(separator: " · ")
    }

    var predictedHoldText: String {
        let cleaned = holdLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? timeWindow : cleaned
    }

    private var primaryCommentaryText: String {
        let review = reviewSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let research = researchSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return review.isEmpty ? research : review
    }

    private func exitPrice(forNetReturnPercent targetReturnPercent: Double) -> Double {
        guard shares > 0 else { return 0 }

        let targetNetValue = max(0, buyTotalCost * (1 + (targetReturnPercent / 100)))
        let percentageGrossValue = targetNetValue / (1 - 0.00047)
        let flatFeeGrossValue = targetNetValue + 0.50
        let grossValue = max(percentageGrossValue, flatFeeGrossValue)

        return max(0, grossValue / Double(shares))
    }

    private func exitNetValue(forPrice price: Double) -> Double {
        guard shares > 0 else { return 0 }
        let grossValue = Double(shares) * price
        let fee = max(0.50, grossValue * 0.00047)
        return max(0, grossValue - fee)
    }
}

struct SyncSnapshot: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let timestamp: Date
}
