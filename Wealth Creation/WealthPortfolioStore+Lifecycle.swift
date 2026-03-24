import Foundation

extension WealthPortfolioStore {
    func reconcileEngineState(
        opportunities: [Opportunity],
        mode: WealthEngineStore.RefreshMode,
        protection: WealthProtectionSettingsStore,
        allowNewOrders: Bool
    ) -> [Opportunity] {
        let now = Date()
        let lookup = Dictionary(
            uniqueKeysWithValues: opportunities.map {
                (activityRuleKey(symbol: $0.symbol, market: $0.market), $0)
            }
        )
        var filledBuys: Set<String> = []

        holdings = refreshLiveHoldings(holdings, using: lookup)
        holdings = holdings.compactMap {
            reconcileHoldingLifecycle(
                $0,
                lookup: lookup,
                protection: protection,
                mode: mode,
                now: now,
                filledBuys: &filledBuys
            )
        }

        let currentQueued = queuedOpportunities.compactMap {
            reconcileQueuedOpportunity($0, lookup: lookup, now: now)
        }
        let currentQueuedByKey = Dictionary(
            uniqueKeysWithValues: currentQueued.map {
                (activityRuleKey(symbol: $0.symbol, market: $0.market), $0)
            }
        )

        let orphanedQueued = currentQueued.filter {
            lookup[activityRuleKey(symbol: $0.symbol, market: $0.market)] == nil
        }

        var spendableCash = currentSpendableCash(using: holdings, queued: orphanedQueued)
        var adjustedByKey: [String: Opportunity] = [:]
        var nextQueued: [Opportunity] = orphanedQueued
        var seenKeys: Set<String> = []

        for orphan in orphanedQueued {
            let key = activityRuleKey(symbol: orphan.symbol, market: orphan.market)
            adjustedByKey[key] = orphan
        }

        for opportunity in rankedLifecycleOpportunities(opportunities) {
            let key = activityRuleKey(symbol: opportunity.symbol, market: opportunity.market)
            seenKeys.insert(key)
            let passesRebuyGate = meetsRebuyGate(opportunity)

            if let holding = holdings.first(where: { $0.symbol == opportunity.symbol && $0.market == opportunity.market }) {
                adjustedByKey[key] = opportunityForHoldingState(
                    opportunity,
                    holding: holding,
                    filledBuys: filledBuys
                )
                continue
            }

            let existingQueued = currentQueuedByKey[key]

            if existingQueued != nil,
               WealthOrderRestrictionRules.canSubmitQueuedBuy(
                   opportunity: opportunity,
                   allowNewOrders: allowNewOrders,
                   spendableCash: spendableCash,
                   passesRebuyGate: passesRebuyGate
               ) {
                adjustedByKey[key] = submitBuy(
                    for: opportunity,
                    now: now,
                    spendableCash: &spendableCash
                )
                continue
            }

            if WealthOrderRestrictionRules.canSubmitImmediateBuy(
                opportunity: opportunity,
                allowNewOrders: allowNewOrders,
                spendableCash: spendableCash,
                passesRebuyGate: passesRebuyGate
            ) {
                adjustedByKey[key] = submitBuy(
                    for: opportunity,
                    now: now,
                    spendableCash: &spendableCash
                )
                continue
            }

            let canQueue = WealthOrderRestrictionRules.canQueueBuy(
                opportunity: opportunity,
                allowNewOrders: allowNewOrders || existingQueued != nil,
                spendableCash: spendableCash,
                passesRebuyGate: passesRebuyGate
            )

            if canQueue {
                let staged = stagedQueuedOpportunity(
                    live: opportunity,
                    queued: existingQueued,
                    now: now
                )
                nextQueued.append(staged)
                adjustedByKey[key] = staged
                spendableCash = max(0, spendableCash - opportunity.trueCost)

                if existingQueued == nil {
                    WealthEventLogStore.shared.record(
                        title: "Buy Queued",
                        detail: "\(opportunity.symbol) queued for next open on \(opportunity.market).",
                        category: "buy",
                        tintName: "blue",
                        timestamp: now
                    )
                }
                continue
            }

            if existingQueued != nil {
                WealthEventLogStore.shared.record(
                    title: "Activity Released",
                    detail: "\(opportunity.symbol) moved out of activity so AI Live can re-rank it again.",
                    category: "buy",
                    tintName: "blue",
                    timestamp: now
                )
            }

            adjustedByKey[key] = opportunity
        }

        queuedOpportunities = nextQueued

        for holding in holdings where holding.orderIntent == .buyPending {
            let key = activityRuleKey(symbol: holding.symbol, market: holding.market)
            if adjustedByKey[key] == nil {
                adjustedByKey[key] = pendingOpportunity(from: holding)
            }
        }

        let adjusted = rankedLifecycleOpportunities(opportunities).map { opportunity in
            let key = activityRuleKey(symbol: opportunity.symbol, market: opportunity.market)
            return adjustedByKey[key] ?? opportunity
        }

        lastRefresh = now
        return adjusted
    }
}
