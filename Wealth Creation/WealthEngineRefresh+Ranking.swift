import SwiftUI

enum WealthEngineRefreshStaging {
    static func stagedBlueprints(
        mode: WealthEngineStore.RefreshMode,
        seededBlueprints: [OpportunityBlueprint],
        scannedMarkets: Set<String>,
        protectedKeys: Set<String>
    ) -> [OpportunityBlueprint] {
        let activeBlueprints = seededBlueprints.filter { scannedMarkets.contains($0.market) }
        let protectedBlueprints = seededBlueprints.filter { protectedKeys.contains(refreshIdentityKey(for: $0)) }
        let primaryBlueprints = primaryBlueprints(
            for: mode,
            activeBlueprints: activeBlueprints,
            usesImportedUniverseSeedSource: WealthEngineStore.isUsingImportedUniverseSeedSource()
        )

        var seenKeys: Set<String> = []
        let staged = (primaryBlueprints + protectedBlueprints).filter { blueprint in
            seenKeys.insert(refreshIdentityKey(for: blueprint)).inserted
        }

        WealthPipelineTraceLogger.logStaged(
            total: staged.count,
            dropped: max(0, seededBlueprints.count - staged.count),
            blueprints: staged,
            scannedMarkets: scannedMarkets,
            protectedKeys: protectedKeys
        )
        WealthPipelineTraceLogger.log(stage: "staged", blueprints: staged)
        return staged
    }

    private static func primaryBlueprints(
        for mode: WealthEngineStore.RefreshMode,
        activeBlueprints: [OpportunityBlueprint],
        usesImportedUniverseSeedSource: Bool
    ) -> [OpportunityBlueprint] {
        switch mode {
        case .startup:
            if usesImportedUniverseSeedSource {
                return activeBlueprints
            }
            return startupBlueprints(from: activeBlueprints)
        case .quick:
            return Array(startupBlueprints(from: activeBlueprints).prefix(4))
        case .soft, .heavy, .deep:
            return activeBlueprints
        }
    }

    private static func startupBlueprints(from activeBlueprints: [OpportunityBlueprint]) -> [OpportunityBlueprint] {
        activeBlueprints.filter(isStartupEligible)
    }

    nonisolated private static func isStartupEligible(_ blueprint: OpportunityBlueprint) -> Bool {
        guard !WealthEngineStore.shouldStayCatalogFirst(blueprint) else { return false }
        guard blueprint.urgency.uppercased() != "IGNORE" else { return false }
        guard blueprint.timeWindow.uppercased() != "UNKNOWN" else { return false }
        return true
    }
}

enum WealthEngineRefreshRanking {
    @MainActor
    static func buildRankedAssets(
        mode: WealthEngineStore.RefreshMode,
        stagedBlueprints: [OpportunityBlueprint],
        activeMarkets: Set<String>,
        protectedKeys: Set<String>,
        previousByKey: [String: Opportunity],
        refreshTime: Date,
        brokerStore: WealthBrokerStore,
        externalData: WealthExternalDataStore,
        goals: WealthGoalVector,
        behavior: WealthBehaviorSettingsStore,
        buyingPower: Double,
        regime: WealthMarketRegime,
        holdings: [Holding],
        currentOpenPositions: Int,
        dailyLossLocked: Bool,
        marketWideBrake: Bool,
        brokerCooldownActive: Bool
    ) -> [Opportunity] {
        let sessionStates = Dictionary(
            uniqueKeysWithValues: stagedBlueprints.map {
                (refreshIdentityKey(for: $0), BrokerSessionClock.state(for: $0.market, brokerName: brokerStore.selectedBroker.name))
            }
        )

        let enrichedBlueprints = stagedBlueprints.map { blueprint in
            makeLiveBlueprint(
                from: blueprint,
                previousByKey: previousByKey,
                sessionState: sessionStates[refreshIdentityKey(for: blueprint)],
                refreshTime: refreshTime,
                externalData: externalData
            )
        }

        let sectorExposure = Dictionary(grouping: holdings, by: \.sector).mapValues(\.count)

        let opportunities = enrichedBlueprints.map { blueprint in
            let sessionState = sessionStates[refreshIdentityKey(for: blueprint)]
                ?? BrokerSessionClock.state(for: blueprint.market, brokerName: brokerStore.selectedBroker.name)

            return makeOpportunity(
                blueprint: blueprint,
                sessionState: sessionState,
                previousByKey: previousByKey,
                refreshTime: refreshTime,
                brokerStore: brokerStore,
                goals: goals,
                behavior: behavior,
                buyingPower: buyingPower,
                regime: regime,
                holdings: holdings,
                duplicateExposureCount: sectorExposure[blueprint.sector] ?? 0,
                currentOpenPositions: currentOpenPositions,
                dailyLossLocked: dailyLossLocked,
                marketWideBrake: marketWideBrake,
                brokerCooldownActive: brokerCooldownActive
            )
        }

        WealthPipelineTraceLogger.logBuilt(
            total: opportunities.count,
            dropped: max(0, stagedBlueprints.count - opportunities.count),
            opportunities: opportunities
        )
        WealthPipelineTraceLogger.log(stage: "built", opportunities: opportunities)

        switch mode {
        case .startup:
            let startupAssets = preservePreMarketOrder(
                opportunities,
                previousByKey: previousByKey,
                refreshTime: refreshTime
            )
            WealthPipelineTraceLogger.log(stage: "startup-pre-market", opportunities: startupAssets)
            return startupAssets

        case .quick, .soft, .heavy, .deep:
            let ranked = rank(opportunities, previousByKey: previousByKey, refreshTime: refreshTime)
            WealthPipelineTraceLogger.log(stage: "ranked", opportunities: ranked)
            return ranked
        }
    }

    @MainActor
    static func buildRankedAssets(
        stagedBlueprints: [OpportunityBlueprint],
        activeMarkets: Set<String>,
        protectedKeys: Set<String>,
        previousByKey: [String: Opportunity],
        refreshTime: Date,
        brokerStore: WealthBrokerStore,
        externalData: WealthExternalDataStore,
        goals: WealthGoalVector,
        behavior: WealthBehaviorSettingsStore,
        buyingPower: Double,
        regime: WealthMarketRegime,
        holdings: [Holding],
        currentOpenPositions: Int,
        dailyLossLocked: Bool,
        marketWideBrake: Bool,
        brokerCooldownActive: Bool
    ) -> [Opportunity] {
        buildRankedAssets(
            mode: .soft,
            stagedBlueprints: stagedBlueprints,
            activeMarkets: activeMarkets,
            protectedKeys: protectedKeys,
            previousByKey: previousByKey,
            refreshTime: refreshTime,
            brokerStore: brokerStore,
            externalData: externalData,
            goals: goals,
            behavior: behavior,
            buyingPower: buyingPower,
            regime: regime,
            holdings: holdings,
            currentOpenPositions: currentOpenPositions,
            dailyLossLocked: dailyLossLocked,
            marketWideBrake: marketWideBrake,
            brokerCooldownActive: brokerCooldownActive
        )
    }

    @MainActor
    private static func preservePreMarketOrder(
        _ opportunities: [Opportunity],
        previousByKey: [String: Opportunity],
        refreshTime: Date
    ) -> [Opportunity] {
        opportunities
            .sorted { lhs, rhs in
                let leftPreviousRank = previousByKey[refreshIdentityKey(for: lhs)]?.rank ?? 0
                let rightPreviousRank = previousByKey[refreshIdentityKey(for: rhs)]?.rank ?? 0
                let leftHasPreviousRank = leftPreviousRank > 0
                let rightHasPreviousRank = rightPreviousRank > 0

                if leftHasPreviousRank != rightHasPreviousRank {
                    return leftHasPreviousRank && !rightHasPreviousRank
                }

                if leftHasPreviousRank && rightHasPreviousRank && leftPreviousRank != rightPreviousRank {
                    return leftPreviousRank < rightPreviousRank
                }

                return marketRankingOrder(lhs, rhs)
            }
            .enumerated()
            .map { index, opportunity in
                let rankedOpportunity = opportunity.withRank(index + 1)
                let previous = previousByKey[refreshIdentityKey(for: rankedOpportunity)]
                let analysisTimestamp = analysisDidChange(for: rankedOpportunity, comparedTo: previous)
                    ? refreshTime
                    : (previous?.analysisTimestamp ?? rankedOpportunity.analysisTimestamp)
                let dataTimestamp = dataDidChange(for: rankedOpportunity, comparedTo: previous)
                    ? refreshTime
                    : (previous?.dataTimestamp ?? rankedOpportunity.dataTimestamp)

                return rankedOpportunity.replacingRankContext(
                    rank: rankedOpportunity.rank,
                    analysisTimestamp: analysisTimestamp,
                    dataTimestamp: dataTimestamp,
                    refreshTime: refreshTime,
                    previous: previous
                )
            }
    }

    nonisolated static func marketQualityTier(for opportunity: Opportunity) -> WealthMarketQualityTier {
        let targetCoverage = opportunity.targetCoveragePercent
        let directivePriority = marketDirectivePriority(opportunity.targetDirective)
        let targetFitPriority = marketTargetFitPriority(opportunity.targetFitLabel)
        let freshnessRank = marketDataFreshnessRank(opportunity.dataQualityLabel)

        if targetCoverage >= 75,
           directivePriority >= 2,
           targetFitPriority >= 2,
           opportunity.aiScore <= 28,
           opportunity.confidence >= 72,
           freshnessRank <= 1 {
            return .top
        }

        if targetCoverage >= 45,
           directivePriority >= 1,
           targetFitPriority >= 1,
           opportunity.aiScore <= 40,
           opportunity.confidence >= 62 {
            return .high
        }

        if targetCoverage >= 20 || (opportunity.aiScore <= 55 && opportunity.confidence >= 50) {
            return .medium
        }

        return .low
    }

    nonisolated static func marketRankingOrder(_ lhs: Opportunity, _ rhs: Opportunity) -> Bool {
        let leftTier = marketQualityTier(for: lhs)
        let rightTier = marketQualityTier(for: rhs)
        if leftTier != rightTier {
            return leftTier.rawValue < rightTier.rawValue
        }

        let leftTargetCoverage = lhs.targetCoveragePercent
        let rightTargetCoverage = rhs.targetCoveragePercent
        if leftTargetCoverage != rightTargetCoverage {
            return leftTargetCoverage > rightTargetCoverage
        }

        let leftDirectivePriority = marketDirectivePriority(lhs.targetDirective)
        let rightDirectivePriority = marketDirectivePriority(rhs.targetDirective)
        if leftDirectivePriority != rightDirectivePriority {
            return leftDirectivePriority > rightDirectivePriority
        }

        let leftTargetFit = marketTargetFitPriority(lhs.targetFitLabel)
        let rightTargetFit = marketTargetFitPriority(rhs.targetFitLabel)
        if leftTargetFit != rightTargetFit {
            return leftTargetFit > rightTargetFit
        }

        if lhs.aiScore != rhs.aiScore { return lhs.aiScore < rhs.aiScore }
        if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
        if lhs.sourceReliabilityScore != rhs.sourceReliabilityScore {
            return lhs.sourceReliabilityScore > rhs.sourceReliabilityScore
        }
        if lhs.shareReliabilityScore != rhs.shareReliabilityScore {
            return lhs.shareReliabilityScore > rhs.shareReliabilityScore
        }
        let leftFreshness = marketDataFreshnessRank(lhs.dataQualityLabel)
        let rightFreshness = marketDataFreshnessRank(rhs.dataQualityLabel)
        if leftFreshness != rightFreshness { return leftFreshness < rightFreshness }
        if lhs.newsScore != rhs.newsScore { return lhs.newsScore > rhs.newsScore }
        return lhs.symbol.localizedStandardCompare(rhs.symbol) == .orderedAscending
    }

    nonisolated private static func marketDirectivePriority(_ directive: String) -> Int {
        let normalized = directive.uppercased()
        if normalized.contains("STRONG") { return 3 }
        if normalized.contains("GOOD") { return 2 }
        if normalized.contains("MODEST") { return 1 }
        return 0
    }

    nonisolated private static func marketTargetFitPriority(_ label: String) -> Int {
        let normalized = label.uppercased()
        if normalized.contains("MISSION") { return 3 }
        if normalized.contains("COMP") || normalized.contains("TARGET") { return 2 }
        if normalized.contains("WATCH") { return 1 }
        return 0
    }

    nonisolated private static func marketDataFreshnessRank(_ label: String) -> Int {
        switch label.uppercased() {
        case "LIVE", "FRESH":
            return 0
        case "AGING":
            return 1
        case "STALE":
            return 2
        default:
            return 3
        }
    }
}

private func refreshIdentityKey(for blueprint: OpportunityBlueprint) -> String {
    wealthRefreshIdentityKey(symbol: blueprint.symbol, market: blueprint.market)
}

private func refreshIdentityKey(for opportunity: Opportunity) -> String {
    wealthRefreshIdentityKey(symbol: opportunity.symbol, market: opportunity.market)
}
