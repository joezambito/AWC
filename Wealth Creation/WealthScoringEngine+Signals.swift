import Foundation

extension WealthScoringEngine {
    static func featureEngineeringLift(
        for blueprint: OpportunityBlueprint,
        advanced: WealthAdvancedSignalProfile,
        isEnabled: (String) -> Bool
    ) -> Double {
        guard isEnabled("Feature Engineering") else { return 0 }
        let consistency = weightedSignalConsistency(
            blueprint.technical,
            blueprint.fundamental,
            blueprint.institutional,
            blueprint.catalyst,
            blueprint.sectorFlow
        )
        let signalBonus = advanced.trendState.contains("TRENDING") ? 2.5 : 0
        return clamp((consistency * 0.18) + signalBonus, min: -3, max: 6)
    }

    static func clusteringLift(
        for blueprint: OpportunityBlueprint,
        holdings: [Holding],
        isEnabled: (String) -> Bool
    ) -> Double {
        guard isEnabled("Cluster Algorithms") || isEnabled("Behavioral Clustering") else { return 0 }
        let sameWindowCount = holdings.filter { $0.timeWindow == blueprint.timeWindow }.count
        let sameSectorCount = holdings.filter { $0.sector == blueprint.sector }.count
        var lift = 0.0
        if isEnabled("Cluster Algorithms") && sameWindowCount == 0 { lift += 2.5 }
        if isEnabled("Behavioral Clustering") && blueprint.speedLabel.uppercased().contains("ACTIVE") { lift += 1.5 }
        if sameSectorCount >= 2 { lift -= 2.0 }
        return lift
    }

    static func regimeClassificationLift(
        for blueprint: OpportunityBlueprint,
        regime: WealthMarketRegime,
        advanced: WealthAdvancedSignalProfile,
        isEnabled: (String) -> Bool
    ) -> Double {
        guard isEnabled("Regime Classification Model") else { return 0 }
        switch regime {
        case .riskOn:
            return blueprint.timeWindow == "HOURS" && advanced.trendState.contains("TRENDING") ? 4 : 1
        case .balanced:
            return advanced.executionState == "EXECUTION CLEAN" ? 2 : 0
        case .defensive:
            return blueprint.timeWindow == "HOURS" ? -4 : (advanced.anomalyState == "STABLE" ? 2 : -1)
        }
    }

    static func dataInfrastructureLift(for blueprint: OpportunityBlueprint, isEnabled: (String) -> Bool) -> Double {
        var lift = 0.0
        if isEnabled("Data Infrastructure") && blueprint.dataQualityLabel == "FRESH" { lift += 2.2 }
        if isEnabled("Historical Feature Store") && blueprint.analysisAge <= 3_600 { lift += 1.0 }
        if isEnabled("Market Replay / Backtest Dataset") && blueprint.timeWindow != "UNKNOWN" { lift += 0.4 }
        if isEnabled("Broker State Memory") && blueprint.dataAge <= 900 { lift += 0.6 }
        if isEnabled("Cache / Snapshot Layer") && blueprint.dataAge <= 300 { lift += 0.6 }
        if isEnabled("Computational Power Layer") {
            lift += computePlatformLift(for: blueprint, isEnabled: isEnabled)
        }
        return min(lift, 3.6)
    }

    static func brokerStateLift(isEnabled: (String) -> Bool) -> Double {
        var lift = 0.0
        let broker = WealthBrokerStore.shared
        let sync = WealthSyncStore.shared
        if isEnabled("Broker Route Selection") && broker.smartRouting { lift += 0.6 }
        if isEnabled("Order Type Selection") && broker.paperTradingEnabled { lift += 0.4 }
        if isEnabled("Broker State Memory") && sync.syncStatus.contains("TWS") { lift += 0.5 }
        if isEnabled("Cloud / Remote Worker Path") && sync.cloudSyncEnabled { lift += 0.25 }
        if isEnabled("Heavy Backtest / Training Jobs") && sync.macBridgeEnabled { lift += 0.25 }
        return min(lift, 1.4)
    }

    static func portfolioHeatPenalty(
        for blueprint: OpportunityBlueprint,
        holdings: [Holding],
        isEnabled: (String) -> Bool
    ) -> Double {
        guard isEnabled("Portfolio Heat Map") || isEnabled("Exposure Balancer") else { return 0 }
        let sameSector = holdings.filter { $0.sector == blueprint.sector }.count
        let sameMarket = holdings.filter { $0.market == blueprint.market }.count
        return (Double(sameSector) * 1.8) + (Double(max(0, sameMarket - 1)) * 1.1)
    }

    private static func weightedSignalConsistency(_ values: Double...) -> Double {
        guard !values.isEmpty else { return 0 }
        let average = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { partial, value in
            let delta = value - average
            return partial + (delta * delta)
        } / Double(values.count)
        let deviation = sqrt(variance)
        return clamp(average - deviation, min: -10, max: 20)
    }

    private static func computePlatformLift(
        for blueprint: OpportunityBlueprint,
        isEnabled: (String) -> Bool
    ) -> Double {
        var lift = 0.0
        if isEnabled("Phone Staged Compute") {
#if targetEnvironment(macCatalyst)
            lift += 0.05
#else
            if blueprint.dataQualityLabel == "FRESH" { lift += 0.35 }
            if blueprint.analysisAge <= 21_600 { lift += 0.15 }
#endif
        }
        if isEnabled("Mac Full Compute") {
#if targetEnvironment(macCatalyst)
            if blueprint.analysisAge <= 86_400 { lift += 0.45 }
            if blueprint.dataAge <= 21_600 { lift += 0.15 }
#else
            lift += 0.05
#endif
        }
        return min(lift, 0.7)
    }
}
