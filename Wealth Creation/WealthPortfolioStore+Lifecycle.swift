import Foundation

extension WealthPortfolioStore {
    func reconcileEngineState(
        opportunities: [Opportunity],
        mode: WealthEngineStore.RefreshMode,
        protection: WealthProtectionSettingsStore,
        allowNewOrders: Bool
    ) -> [Opportunity] {
        let engine = WealthEngineStore.shared
        let now = Date()
        let buildMarketStage: (Set<String>, Set<String>, Set<String>) -> (review: [Opportunity], market: [Opportunity]) = { activityKeys, holdingKeys, livePickKeys in
            let review = WealthAllCardsStore.reviewCards(
                from: opportunities,
                activityKeys: activityKeys,
                holdingKeys: holdingKeys,
                livePickKeys: livePickKeys
            )
            let market = WealthAllCardsStore.marketCards(
                from: review,
                limit: WealthAllCardsStore.marketCardLimit
            )
            return (review, market)
        }
        let lookup = Dictionary(
            uniqueKeysWithValues: opportunities.map {
                (activityRuleKey(symbol: $0.symbol, market: $0.market), $0)
            }
        )
        let currentActivityKeys = Set(queuedOpportunities.map {
            activityRuleKey(symbol: $0.symbol, market: $0.market)
        })
        let holdingKeys = Set(holdings.map {
            activityRuleKey(symbol: $0.symbol, market: $0.market)
        })
        let initialStage = buildMarketStage(currentActivityKeys, holdingKeys, [])
        let reviewCandidates = initialStage.review
        WealthPipelineTraceLogger.log(stage: "review", opportunities: reviewCandidates)
        let marketCandidates = initialStage.market
        WealthPipelineTraceLogger.log(stage: "market", opportunities: marketCandidates)
        let marketCandidatesByKey = Dictionary(
            uniqueKeysWithValues: marketCandidates.map {
                (activityRuleKey(symbol: $0.symbol, market: $0.market), $0)
            }
        )
        var filledBuys: Set<String> = []

        holdings = refreshLiveHoldings(
            holdings,
            using: lookup,
            rankedMarketLookup: marketCandidatesByKey
        )
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
            reconcileQueuedOpportunity(
                $0,
                lookup: lookup,
                rankedMarketLookup: marketCandidatesByKey,
                now: now
            )
        }
        let currentQueuedByKey = Dictionary(
            uniqueKeysWithValues: currentQueued.map {
                (activityRuleKey(symbol: $0.symbol, market: $0.market), $0)
            }
        )
        let refreshedActivityKeys = Set(currentQueued.map {
            activityRuleKey(symbol: $0.symbol, market: $0.market)
        })
        let refreshedHoldingKeys = Set(holdings.map {
            activityRuleKey(symbol: $0.symbol, market: $0.market)
        })

        let orphanedQueued = currentQueued.filter {
            lookup[activityRuleKey(symbol: $0.symbol, market: $0.market)] == nil
        }

        var spendableCash = currentSpendableCash(using: holdings, queued: currentQueued)
        let refreshedStage = buildMarketStage(refreshedActivityKeys, refreshedHoldingKeys, [])
        let refreshedReviewCandidates = refreshedStage.review
        WealthPipelineTraceLogger.log(stage: "review", opportunities: refreshedReviewCandidates)
        let refreshedMarketCandidates = refreshedStage.market
        WealthPipelineTraceLogger.log(stage: "market", opportunities: refreshedMarketCandidates)
        let refreshedMarketCandidatesByKey = Dictionary(
            uniqueKeysWithValues: refreshedMarketCandidates.map {
                (activityRuleKey(symbol: $0.symbol, market: $0.market), $0)
            }
        )
        let marketRequestCandidates = WealthOpportunityLaneRules.aiLiveMarketRequestSet(
            from: refreshedMarketCandidates,
            activityKeys: refreshedActivityKeys,
            holdingKeys: refreshedHoldingKeys,
            limit: WealthAllCardsStore.marketCardLimit
        )
        WealthPipelineTraceLogger.log(stage: "ai_live_input", opportunities: marketRequestCandidates)
        let aiLiveEvaluation = WealthAILiveCoordinator.evaluate(
            opportunities: marketRequestCandidates,
            currentActivity: currentQueued,
            holdings: holdings,
            spendableCash: spendableCash + currentQueued.reduce(0) { $0 + $1.trueCost },
            returnedFromActivity: engine.activityRefusalsByKey
        )
        let acceptedKeys = aiLiveEvaluation.promotedKeys
        let acceptedCandidates = marketRequestCandidates.filter {
            acceptedKeys.contains(activityRuleKey(symbol: $0.symbol, market: $0.market))
        }
        WealthPipelineTraceLogger.log(stage: "ai_live_accepted", opportunities: acceptedCandidates)
        let visibleStage = buildMarketStage(refreshedActivityKeys, refreshedHoldingKeys, acceptedKeys)
        WealthPipelineTraceLogger.log(stage: "review_visible", opportunities: visibleStage.review)
        WealthPipelineTraceLogger.log(stage: "market_visible", opportunities: visibleStage.market)
        engine.aiLiveResultsByKey = aiLiveEvaluation.resultsByKey
        var adjustedByKey: [String: Opportunity] = [:]
        var nextQueued: [Opportunity] = orphanedQueued
        var seenKeys: Set<String> = []
        var nextActivityRefusals = engine.activityRefusalsByKey.filter { lookup[$0.key] != nil }
        var activityAcceptedCount = 0
        var activityRejectedCount = 0

        for orphan in orphanedQueued {
            let key = activityRuleKey(symbol: orphan.symbol, market: orphan.market)
            adjustedByKey[key] = orphan
        }

        for opportunity in rankedLifecycleOpportunities(opportunities) {
            let key = activityRuleKey(symbol: opportunity.symbol, market: opportunity.market)
            let stageOpportunity = refreshedMarketCandidatesByKey[key] ?? opportunity.withRank(0)
            seenKeys.insert(key)
            let passesRebuyGate = meetsRebuyGate(stageOpportunity)
            let aiLivePromoted = aiLiveEvaluation.promotedKeys.contains(key)
            let aiLiveResult = aiLiveEvaluation.resultsByKey[key]

            if let holding = holdings.first(where: { $0.symbol == opportunity.symbol && $0.market == opportunity.market }) {
                nextActivityRefusals.removeValue(forKey: key)
                adjustedByKey[key] = opportunityForHoldingState(
                    stageOpportunity,
                    holding: holding,
                    filledBuys: filledBuys
                )
                continue
            }

            let existingQueued = currentQueuedByKey[key]

            if !aiLivePromoted {
                if let existingQueued {
                    let detail: String
                    if let replacingKey = aiLiveEvaluation.replacedByOldKey[key] {
                        detail = "\(existingQueued.symbol) left activity because \(replacingKey) took its place."
                    } else {
                        detail = "\(existingQueued.symbol) moved out of activity so AI Live can re-rank it again."
                    }

                    WealthEventLogStore.shared.record(
                        title: "Activity Released",
                        detail: detail,
                        category: "buy",
                        tintName: "blue",
                        timestamp: now
                    )
                }

                adjustedByKey[key] = stageOpportunity
                continue
            }

            switch WealthOrderRestrictionRules.activityAdmissionDecision(
                opportunity: stageOpportunity,
                aiLive: aiLiveResult,
                allowNewOrders: allowNewOrders || existingQueued != nil,
                spendableCash: spendableCash,
                passesRebuyGate: passesRebuyGate,
                hasExistingQueued: existingQueued != nil
            ) {
            case .reject(let rejectReason):
                activityRejectedCount += 1
                if existingQueued != nil {
                    WealthEventLogStore.shared.record(
                        title: "Activity Rejected",
                        detail: "\(stageOpportunity.symbol) left activity because \(rejectReason).",
                        category: "buy",
                        tintName: "orange",
                        timestamp: now
                    )
                }
                nextActivityRefusals[key] = WealthActivityRefusalHandoff(
                    key: key,
                    symbol: stageOpportunity.symbol,
                    market: stageOpportunity.market,
                    state: .activityRejected,
                    reason: rejectReason,
                    timestamp: now
                )
                adjustedByKey[key] = stageOpportunity
                continue

            case .submitQueued, .submitImmediate:
                activityAcceptedCount += 1
                nextActivityRefusals.removeValue(forKey: key)
                adjustedByKey[key] = submitBuy(
                    for: stageOpportunity,
                    now: now,
                    spendableCash: &spendableCash
                )
                continue

            case .queue:
                let staged = stagedQueuedOpportunity(
                    live: stageOpportunity,
                    queued: existingQueued,
                    now: now
                )
                activityAcceptedCount += 1
                nextActivityRefusals.removeValue(forKey: key)
                nextQueued.append(staged)
                adjustedByKey[key] = staged
                spendableCash = max(0, spendableCash - stageOpportunity.trueCost)

                if existingQueued == nil {
                    WealthEventLogStore.shared.record(
                        title: "Buy Queued",
                        detail: "\(stageOpportunity.symbol) queued for next open on \(stageOpportunity.market).",
                        category: "buy",
                        tintName: "blue",
                        timestamp: now
                    )
                }
                continue
            }
        }

        let activityKeysFinal = Set(nextQueued.map { activityRuleKey(symbol: $0.symbol, market: $0.market) })
        let marketKeysFinal = Set(refreshedMarketCandidates.map { activityRuleKey(symbol: $0.symbol, market: $0.market) })
        let pipelineStateValid = activityKeysFinal.isSubset(of: acceptedKeys) && acceptedKeys.isSubset(of: marketKeysFinal)
        if !pipelineStateValid {
#if DEBUG
            assertionFailure("Invalid AI Live to Activity pipeline state")
#endif
            WealthEventLogStore.shared.record(
                title: "Pipeline Rejected",
                detail: "Activity accepted cards outside the AI Live promoted Market set.",
                category: "refresh",
                tintName: "red",
                timestamp: now
            )
            nextQueued = nextQueued.filter {
                let queuedKey = activityRuleKey(symbol: $0.symbol, market: $0.market)
                return acceptedKeys.contains(queuedKey) && marketKeysFinal.contains(queuedKey)
            }
        }

        #if DEBUG
        if WealthPipelineTraceLogger.isEnabledForDebugOutput {
            NSLog(
                "[CardFlow] aiLive input=%ld accepted=%ld",
                marketRequestCandidates.count,
                acceptedCandidates.count
            )
            NSLog(
                "[CardFlow] activity input=%ld accepted=%ld rejected=%ld",
                acceptedCandidates.count,
                activityAcceptedCount,
                activityRejectedCount
            )
        }
        #endif

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

        let survivingKeys = Set(adjusted.map { activityRuleKey(symbol: $0.symbol, market: $0.market) })
        nextActivityRefusals = nextActivityRefusals.filter { survivingKeys.contains($0.key) }
        engine.replaceActivityRefusals(with: nextActivityRefusals)

        lastRefresh = now
        return adjusted
    }
}
