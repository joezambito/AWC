import Foundation

extension WealthPortfolioStore {
    var activityMissingDataGrace: TimeInterval { 20 * 60 }

    func refreshLiveHoldings(
        _ holdings: [Holding],
        using lookup: [String: Opportunity]
    ) -> [Holding] {
        holdings.map { holding in
            let key = activityRuleKey(symbol: holding.symbol, market: holding.market)
            guard let live = lookup[key] else { return holding }

            var next = holding
            next.currentPrice = WealthHoldingLivePriceResolver.resolvedCurrentPrice(
                currentPrice: holding.currentPrice,
                livePrice: live.price,
                averagePrice: holding.averagePrice
            )
            next.aiScore = live.aiScore
            next.aiBand = live.rank
            next.confidence = live.confidence
            next.safety = live.safety
            next.prospect = live.prospect
            next.timeWindow = live.timeWindow
            next.riskLabel = live.aiRiskStance
            next.holdLabel = live.predictedHoldText
            next.safeKeepLabel = live.targetDirective
            next.lockLabel = live.capitalDisciplineLabel
            next.sourceTrigger = live.sourceTrigger
            next.dataOrigin = live.dataOrigin
            next.reviewSummary = live.reviewSummary
            next.researchSummary = live.sourceSummary
            next.analysisTimestamp = live.analysisTimestamp
            next.dataTimestamp = live.dataTimestamp
            next.lastRefreshTimestamp = live.lastRefreshTimestamp
            return next
        }
    }

    func reconcileHoldingLifecycle(
        _ holding: Holding,
        lookup: [String: Opportunity],
        protection: WealthProtectionSettingsStore,
        mode: WealthEngineStore.RefreshMode,
        now: Date,
        filledBuys: inout Set<String>
    ) -> Holding? {
        var next = holding
        let key = activityRuleKey(symbol: holding.symbol, market: holding.market)
        let liveOpportunity = lookup[key]
        let sessionOpen = BrokerSessionClock.state(
            for: holding.market,
            brokerName: WealthBrokerStore.shared.selectedBroker.name,
            date: now
        ).canTradeNow

        switch holding.orderIntent {
        case .buyPending:
            let age = now.timeIntervalSince(holding.orderSubmittedAt ?? now)

            if let cancelReason = submittedBuyCancellationReason(
                holding: next,
                live: liveOpportunity,
                now: now
            ) {
                setBuyCooldown(
                    until: now.addingTimeInterval(failedBuyCooldown),
                    for: next.symbol,
                    market: next.market,
                    reason: "AI cancelled the buy because \(cancelReason)"
                )
                WealthEventLogStore.shared.record(
                    title: "Buy Cancelled",
                    detail: "\(next.symbol) buy cancelled because \(cancelReason).",
                    category: "buy",
                    tintName: "orange",
                    timestamp: now
                )
                return nil
            }

            if sessionOpen && (age >= 18 || mode == .deep) {
                settleBuy(for: next)
                next.orderIntent = .live
                next.orderState = .filled
                next.orderSubmittedAt = nil
                next.filledAt = now
                filledBuys.insert(key)
                WealthEventLogStore.shared.record(
                    title: "Buy Filled",
                    detail: "\(next.symbol) buy filled at \(WealthFormat.money(next.averagePrice)).",
                    category: "buy",
                    tintName: "green",
                    timestamp: now
                )
            } else {
                next.orderState = age >= 8 ? .pending : .submitted
            }

            next.lastRefreshTimestamp = now
            return next

        case .sellPending:
            let age = now.timeIntervalSince(holding.orderSubmittedAt ?? now)
            let shouldStillSell = shouldTriggerSell(next, protection: protection)
            next.submittedExitPrice = next.currentPrice

            if !shouldStillSell {
                next.orderIntent = .live
                next.orderState = .ready
                next.pendingShares = 0
                next.submittedExitPrice = nil
                next.orderSubmittedAt = nil
                next.lastRefreshTimestamp = now
                return next
            }

            if sessionOpen && (age >= 18 || mode == .deep) {
                recordCompletedActivity(Self.completedSellSnapshot(from: next, completedAt: now), now: now)
                WealthEventLogStore.shared.record(
                    title: "Sell Filled",
                    detail: "\(next.symbol) sell completed with net \(WealthFormat.money(next.pendingNetValue)).",
                    category: "sell",
                    tintName: "orange",
                    timestamp: now
                )
                settleSell(for: next)
                return nil
            }

            next.orderState = age >= 8 ? .pending : .submitted
            next.lastRefreshTimestamp = now
            return next

        case .live:
            let protectiveExitTriggered = liveOpportunity.map {
                WealthAISafeguards.shouldForceProtectiveSell(live: $0, holding: next)
            } ?? false

            if shouldTriggerSell(next, protection: protection) || protectiveExitTriggered {
                next.orderIntent = .sellPending
                next.orderState = .submitted
                next.pendingShares = next.shares
                next.submittedExitPrice = next.currentPrice
                next.orderSubmittedAt = now
            }

            next.lastRefreshTimestamp = now
            return next
        }
    }

    func reconcileQueuedOpportunity(
        _ queued: Opportunity,
        lookup: [String: Opportunity],
        now: Date
    ) -> Opportunity? {
        let key = activityRuleKey(symbol: queued.symbol, market: queued.market)

        guard let live = lookup[key] else {
            guard shouldHoldMissingActivityCard(queued.lastRefreshTimestamp, now: now) else {
                WealthEventLogStore.shared.record(
                    title: "Activity Rejected",
                    detail: "\(queued.symbol) left activity because live data stopped updating.",
                    category: "buy",
                    tintName: "orange",
                    timestamp: now
                )
                return nil
            }

            return queued.withLastRefresh(now)
        }

        guard let rejectReason = activityRejectReason(for: live) else {
            let submittedPrice = queued.submittedPrice > 0 ? queued.submittedPrice : live.submittedPrice
            let submittedShares = max(queued.submittedShares, live.recommendedShares)

            return live
                .withOrderState(
                    .ready,
                    submittedPrice: submittedPrice,
                    submittedShares: submittedShares
                )
                .withLastRefresh(now)
        }

        WealthEventLogStore.shared.record(
            title: "Activity Rejected",
            detail: "\(queued.symbol) left activity because \(rejectReason).",
            category: "buy",
            tintName: "orange",
            timestamp: now
        )
        return nil
    }

    func activityRuleKey(symbol: String, market: String) -> String {
        "\(symbol.uppercased())-\(market.uppercased())"
    }

    func rankedLifecycleOpportunities(_ opportunities: [Opportunity]) -> [Opportunity] {
        opportunities.sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            if lhs.aiScore != rhs.aiScore { return lhs.aiScore < rhs.aiScore }
            if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
            return lhs.symbol.localizedStandardCompare(rhs.symbol) == .orderedAscending
        }
    }

    func stagedQueuedOpportunity(
        live: Opportunity,
        queued: Opportunity?,
        now: Date
    ) -> Opportunity {
        let submittedPrice = queued.map { $0.submittedPrice > 0 ? $0.submittedPrice : live.submittedPrice } ?? live.submittedPrice
        let submittedShares = max(queued?.submittedShares ?? 0, live.recommendedShares)

        return live
            .withOrderState(
                .ready,
                submittedPrice: submittedPrice,
                submittedShares: submittedShares
            )
            .withLastRefresh(now)
    }

    func activityRejectReason(for live: Opportunity) -> String? {
        if !meetsRebuyGate(live) {
            return "rebuy protection is active"
        }
        if live.permission != .go {
            return "AI permission is no longer GO"
        }
        if !live.isGreenBuyReady || live.cardSignalLabel != "GREEN" {
            return "the card is no longer green"
        }
        if live.dataQualityLabel.uppercased() == "STALE" {
            return "the live data is stale"
        }
        if live.expectedNetProfit <= 0 {
            return "projected net profit dropped below costs"
        }
        if live.recommendedShares <= 0 || live.trueCost <= 0 {
            return "the position size is no longer valid"
        }
        if live.earningsEventRisk >= 70 || live.macroEventRisk >= 75 {
            return "event risk spiked too high"
        }
        return nil
    }

    func submittedBuyCancellationReason(
        holding: Holding,
        live: Opportunity?,
        now: Date
    ) -> String? {
        if let live {
            if let rejectReason = activityRejectReason(for: live) {
                return rejectReason
            }
            return nil
        }

        guard !shouldHoldMissingActivityCard(holding.lastRefreshTimestamp, now: now) else {
            return nil
        }

        return "live data stopped updating"
    }

    func shouldHoldMissingActivityCard(_ lastRefresh: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastRefresh) <= activityMissingDataGrace
    }
}
