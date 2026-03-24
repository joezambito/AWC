import Foundation

extension WealthPortfolioStore {
    func settleBuy(for holding: Holding) {
        let cost = buyCost(for: holding.shares, price: holding.averagePrice)
        if WealthProtectionSettingsStore.shared.demoMode {
            WealthProtectionSettingsStore.shared.demoBalance = max(0, WealthProtectionSettingsStore.shared.demoBalance - cost)
        } else {
            WealthBrokerStore.shared.debitExecutionBalance(cost)
        }
    }

    func settleSell(for holding: Holding) {
        let net = holding.pendingNetValue
        let soldAt = Date()

        if WealthProtectionSettingsStore.shared.demoMode {
            WealthProtectionSettingsStore.shared.demoBalance += net
        } else {
            WealthBrokerStore.shared.creditExecutionBalance(net)
        }

        recordSoldPrice(
            holding.submittedExitPrice ?? holding.effectiveCurrentPrice,
            for: holding.symbol,
            market: holding.market,
            soldAt: soldAt
        )

        let fastExit = holding.filledAt.map { soldAt.timeIntervalSince($0) <= fastSellCooldown } ?? false
        guard holding.netPnL < 0 || fastExit else { return }

        let reason = holding.netPnL < 0
            ? "AI sold this share at a loss, so a cooldown is active before it can be bought again."
            : "AI sold this share quickly, so a cooldown is active before it can be bought again."

        setBuyCooldown(
            until: soldAt.addingTimeInterval(fastSellCooldown),
            for: holding.symbol,
            market: holding.market,
            reason: reason
        )
    }

    func buyCost(for shares: Int, price: Double) -> Double {
        let subtotal = Double(shares) * price
        return subtotal + WealthScoringEngine.feeEstimate(for: subtotal)
    }

    func makePendingHolding(from opportunity: Opportunity, now: Date) -> Holding {
        Holding(
            symbol: opportunity.symbol,
            market: opportunity.market,
            sector: opportunity.sector,
            shares: opportunity.recommendedShares,
            averagePrice: opportunity.submittedPrice,
            currentPrice: opportunity.price,
            aiScore: opportunity.aiScore,
            aiBand: opportunity.rank,
            confidence: opportunity.confidence,
            safety: opportunity.safety,
            prospect: opportunity.prospect,
            timeWindow: opportunity.timeWindow,
            riskLabel: opportunity.aiRiskStance,
            holdLabel: opportunity.predictedHoldText,
            safeKeepLabel: opportunity.targetDirective,
            lockLabel: opportunity.capitalDisciplineLabel,
            sourceTrigger: opportunity.sourceTrigger,
            dataOrigin: opportunity.dataOrigin,
            reviewSummary: opportunity.reviewSummary,
            researchSummary: opportunity.sourceSummary,
            analysisTimestamp: opportunity.analysisTimestamp,
            dataTimestamp: opportunity.dataTimestamp,
            lastRefreshTimestamp: opportunity.lastRefreshTimestamp,
            filledAt: nil,
            orderIntent: .buyPending,
            orderState: .submitted,
            pendingShares: 0,
            submittedExitPrice: nil,
            orderSubmittedAt: now
        )
    }

    func pendingOpportunity(from holding: Holding) -> Opportunity {
        let warningReason = holding.orderIntent == .buyPending
            ? "Pending order stays under review until fresh market data confirms the setup."
            : ""

        return Opportunity(
            rank: holding.aiBand,
            symbol: holding.symbol,
            market: holding.market,
            sector: holding.sector,
            aiScore: holding.aiScore,
            confidence: holding.confidence,
            safety: holding.safety,
            probabilityOfSuccess: max(holding.confidence, holding.safety),
            newsScore: 0,
            recommendedShares: holding.shares,
            price: holding.effectiveCurrentPrice,
            brokerFee: WealthScoringEngine.feeEstimate(for: Double(holding.shares) * holding.averagePrice),
            expectedProfit: max(0, (holding.effectiveCurrentPrice - holding.averagePrice) * Double(holding.shares)),
            prospect: holding.prospect,
            timeToTarget: holding.holdLabel,
            timeWindow: holding.timeWindow,
            catalystBucket: "Pending Order Tracking",
            sourceTrigger: holding.sourceTrigger,
            dataOrigin: holding.dataOrigin,
            sourceSummary: holding.researchSummary,
            reviewSummary: holding.reviewSummary,
            intelligenceDrivers: [],
            intelligenceChannels: [],
            urgency: holding.orderState == .submitted ? "SUBMITTED" : "PENDING",
            priceChangePercent: holding.percentChange,
            targetFitLabel: "ACTIVE",
            speedLabel: "BROKER",
            capitalFitLabel: "RESERVED",
            dataQualityLabel: "LIVE",
            analysisTimestamp: holding.analysisTimestamp,
            dataTimestamp: holding.dataTimestamp,
            lastRefreshTimestamp: holding.lastRefreshTimestamp,
            brokerName: WealthBrokerStore.shared.selectedBroker.name,
            orderState: holding.orderState,
            submittedPrice: holding.averagePrice,
            submittedShares: holding.shares,
            decisionBias: .buy,
            aggressionMode: .moderate,
            marketRegime: .balanced,
            targetPressureLabel: holding.safeKeepLabel,
            capitalDisciplineLabel: holding.lockLabel,
            allocationPercent: 0,
            positionSizePercent: 0,
            conviction: .strong,
            permission: .go,
            rotationBias: .keep,
            hungerMode: .stalk,
            executionStyle: .staged,
            commandText: "ORDER TRACKING",
            priorityScore: holding.aiScore,
            targetDirective: holding.safeKeepLabel,
            targetCoveragePercent: 0,
            sourceReliabilityScore: holding.confidence,
            shareReliabilityScore: holding.safety,
            optionsFlowStrength: 0,
            darkPoolStrength: 0,
            insiderStrength: 0,
            filingStrength: 0,
            earningsEventRisk: 0,
            macroEventRisk: 0,
            trustState: .verified,
            trustReason: "Pending confirmation. The AI is holding this until the latest data confirms the setup again.",
            buyReason: holding.aiCommentary,
            rotationReason: holding.holdLabel,
            warningReason: warningReason,
            advancedSignal: .neutral,
            previousAiScore: nil,
            previousConfidence: nil
        )
    }
}
