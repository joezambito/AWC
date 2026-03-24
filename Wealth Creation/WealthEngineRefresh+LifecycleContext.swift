import Foundation

extension WealthEngineStore {
    func refreshContext(at refreshTime: Date) -> WealthRefreshContext {
        let brokerStore = WealthBrokerStore.shared
        let behaviorStore = WealthBehaviorSettingsStore.shared
        let portfolio = WealthPortfolioStore.shared
        let externalData = WealthExternalDataStore.shared
        let holdings = portfolio.holdings

        return WealthRefreshContext(
            brokerStore: brokerStore,
            behaviorStore: behaviorStore,
            portfolio: portfolio,
            externalData: externalData,
            scannedMarkets: activeScanMarketsForCurrentCycle(date: refreshTime, brokerName: brokerStore.selectedBroker.name),
            activeMarkets: activeExecutionMarkets(),
            buyingPower: max(0, portfolio.freeBuyingPower),
            goals: portfolio.goalVector(),
            holdings: holdings,
            protectedKeys: Set(
                holdings.map { wealthRefreshIdentityKey(symbol: $0.symbol, market: $0.market) } +
                portfolio.queuedOpportunities.map { wealthRefreshIdentityKey(symbol: $0.symbol, market: $0.market) }
            ),
            previousByKey: Dictionary(
                uniqueKeysWithValues: rankedAssets.map {
                    (wealthRefreshIdentityKey(symbol: $0.symbol, market: $0.market), $0)
                }
            ),
            dailyLossLocked: WealthAISafeguards.dailyLossLocked(portfolio: portfolio),
            marketWideBrake: false,
            currentOpenPositions: holdings.filter { $0.orderIntent != .sellPending }.count,
            brokerCooldownActive: brokerStore.rejectionCooldownActive
        )
    }

    func scannedSignalsForMode(_ mode: RefreshMode, opportunities: [Opportunity]) -> [MarketSignal] {
        let liveSignals = Self.marketSignals(from: opportunities)

        switch mode {
        case .startup:
            return Array(liveSignals.prefix(2))
        case .quick:
            return Array(liveSignals.prefix(4))
        case .soft:
            return Array(liveSignals.prefix(6))
        case .heavy, .deep:
            return liveSignals
        }
    }

    func refreshModeLabel(_ mode: RefreshMode) -> String {
        switch mode {
        case .startup: return "STARTUP"
        case .quick: return "QUICK"
        case .soft: return "SOFT"
        case .heavy: return "HEAVY"
        case .deep: return "DEEP"
        }
    }

    func setActivationState(for mode: RefreshMode) {
        switch mode {
        case .startup: activationStage = 1
        case .quick, .soft, .heavy, .deep: activationStage = activationStageTotal
        }

        activationCycleComplete = false
    }
}

struct WealthRefreshContext {
    let brokerStore: WealthBrokerStore
    let behaviorStore: WealthBehaviorSettingsStore
    let portfolio: WealthPortfolioStore
    let externalData: WealthExternalDataStore
    let scannedMarkets: Set<String>
    let activeMarkets: Set<String>
    let buyingPower: Double
    let goals: WealthGoalVector
    let holdings: [Holding]
    let protectedKeys: Set<String>
    let previousByKey: [String: Opportunity]
    let dailyLossLocked: Bool
    let marketWideBrake: Bool
    let currentOpenPositions: Int
    let brokerCooldownActive: Bool
}

func wealthRefreshIdentityKey(symbol: String, market: String) -> String {
    "\(symbol.uppercased())-\(market.uppercased())"
}
