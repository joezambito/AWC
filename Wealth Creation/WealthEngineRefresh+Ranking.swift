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
        let primaryBlueprints = primaryBlueprints(for: mode, activeBlueprints: activeBlueprints)

        var seenKeys: Set<String> = []
        return (primaryBlueprints + protectedBlueprints).filter { blueprint in
            seenKeys.insert(refreshIdentityKey(for: blueprint)).inserted
        }
    }

    private static func primaryBlueprints(
        for mode: WealthEngineStore.RefreshMode,
        activeBlueprints: [OpportunityBlueprint]
    ) -> [OpportunityBlueprint] {
        switch mode {
        case .startup:
            return Array(activeBlueprints.prefix(2))
        case .quick:
            return Array(activeBlueprints.prefix(4))
        case .soft, .heavy, .deep:
            return activeBlueprints
        }
    }
}

enum WealthEngineRefreshRanking {
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
        let sessionStates = Dictionary(
            uniqueKeysWithValues: stagedBlueprints.map {
                (refreshIdentityKey(for: $0), BrokerSessionClock.state(for: $0.market, brokerName: brokerStore.selectedBroker.name))
            }
        )

        let liveBlueprints = stagedBlueprints
            .filter { activeMarkets.contains($0.market) || protectedKeys.contains(refreshIdentityKey(for: $0)) }
        WealthBrokerQuoteStore.shared.prepareSubscriptions(for: liveBlueprints)

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

        return rank(opportunities, previousByKey: previousByKey, refreshTime: refreshTime)
    }
}

private func refreshIdentityKey(for blueprint: OpportunityBlueprint) -> String {
    wealthRefreshIdentityKey(symbol: blueprint.symbol, market: blueprint.market)
}
