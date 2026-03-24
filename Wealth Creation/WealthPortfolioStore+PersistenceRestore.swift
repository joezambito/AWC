import Foundation
import SwiftUI
import Combine

extension WealthPortfolioStore {
    static func purgeLegacyPortfolioStorage(from defaults: UserDefaults) {
        let currentVersion = defaults.integer(forKey: migrationKey)
        guard currentVersion < migrationVersion else { return }
        defaults.set(migrationVersion, forKey: migrationKey)
    }

    static func loadPersistedHoldings(from defaults: UserDefaults) -> [Holding] {
        guard
            let data = defaults.data(forKey: StorageKey.holdings),
            let payload = try? JSONDecoder().decode([PersistedHolding].self, from: data)
        else {
            return []
        }

        return payload.map { item in
            Holding(
                symbol: item.symbol,
                market: item.market,
                sector: item.sector,
                shares: item.shares,
                averagePrice: item.averagePrice,
                currentPrice: WealthHoldingLivePriceResolver.resolvedCurrentPrice(
                    currentPrice: item.currentPrice,
                    livePrice: 0,
                    averagePrice: item.averagePrice
                ),
                aiScore: item.aiScore,
                aiBand: item.aiBand,
                confidence: item.confidence,
                safety: item.safety,
                prospect: item.prospect,
                timeWindow: item.timeWindow,
                riskLabel: item.riskLabel,
                holdLabel: item.holdLabel,
                safeKeepLabel: item.safeKeepLabel,
                lockLabel: item.lockLabel,
                sourceTrigger: item.sourceTrigger,
                dataOrigin: item.dataOrigin,
                reviewSummary: item.reviewSummary,
                researchSummary: item.researchSummary,
                analysisTimestamp: item.analysisTimestamp,
                dataTimestamp: item.dataTimestamp,
                lastRefreshTimestamp: item.lastRefreshTimestamp ?? item.analysisTimestamp,
                filledAt: item.filledAt,
                orderIntent: HoldingOrderIntent(rawValue: item.orderIntentRaw) ?? .live,
                orderState: OrderExecutionState(rawValue: item.orderStateRaw) ?? .ready,
                pendingShares: item.pendingShares,
                submittedExitPrice: item.submittedExitPrice,
                orderSubmittedAt: item.orderSubmittedAt
            )
        }
    }

    static func restoreQueuedOpportunities(from defaults: UserDefaults) -> [Opportunity] {
        loadPersistedQueuedOpportunities(from: defaults).filter { opportunity in
            switch opportunity.orderState {
            case .ready:
                return true
            case .submitted, .pending, .partial:
                return true
            case .filled:
                return false
            }
        }
    }

    static func loadPersistedCompletedActivity(from defaults: UserDefaults) -> [Opportunity] {
        guard
            let data = defaults.data(forKey: StorageKey.completedActivity),
            let payload = try? JSONDecoder().decode([PersistedOpportunity].self, from: data)
        else {
            return []
        }

        return payload.map { item in
            restorePersistedOpportunity(from: item)
        }
    }

    static func restoredReservedOrderCapital(
        holdings: [Holding],
        queuedOpportunities: [Opportunity]
    ) -> Double {
        let pendingHoldingReserve = holdings
            .filter { $0.orderIntent == .buyPending }
            .reduce(0) { subtotal, holding in
                let fillSubtotal = Double(holding.shares) * holding.averagePrice
                return subtotal + fillSubtotal + WealthScoringEngine.feeEstimate(for: fillSubtotal)
            }

        let queuedReserve = queuedOpportunities.reduce(0) { $0 + $1.trueCost }
        return max(0, pendingHoldingReserve + queuedReserve)
    }

    static func loadPersistedQueuedOpportunities(from defaults: UserDefaults) -> [Opportunity] {
        guard
            let data = defaults.data(forKey: StorageKey.queuedOpportunities),
            let payload = try? JSONDecoder().decode([PersistedOpportunity].self, from: data)
        else {
            return []
        }

        return payload.map { item in
            restorePersistedOpportunity(from: item)
        }
    }

    static func loadPersistedSaleGates(from defaults: UserDefaults) -> [String: PersistedSaleGate] {
        guard
            let data = defaults.data(forKey: StorageKey.saleGates),
            let payload = try? JSONDecoder().decode([PersistedSaleGate].self, from: data)
        else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: payload.map { ($0.key, $0) })
    }

    static func prunedCompletedActivity(_ opportunities: [Opportunity], now: Date = .now) -> [Opportunity] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        return Array(
            opportunities
                .filter { $0.lastRefreshTimestamp >= cutoff }
                .sorted { $0.lastRefreshTimestamp > $1.lastRefreshTimestamp }
                .prefix(12)
        )
    }

    private static func restorePersistedOpportunity(from item: PersistedOpportunity) -> Opportunity {
        Opportunity(
            rank: item.rank,
            symbol: item.symbol,
            market: item.market,
            sector: item.sector,
            aiScore: item.aiScore,
            confidence: item.confidence,
            safety: item.safety,
            probabilityOfSuccess: item.probabilityOfSuccess,
            newsScore: item.newsScore,
            recommendedShares: item.recommendedShares,
            price: item.price,
            brokerFee: item.brokerFee,
            expectedProfit: item.expectedProfit,
            prospect: item.prospect,
            timeToTarget: item.timeToTarget,
            timeWindow: item.timeWindow,
            catalystBucket: item.catalystBucket,
            sourceTrigger: item.sourceTrigger,
            dataOrigin: item.dataOrigin,
            sourceSummary: item.sourceSummary,
            reviewSummary: item.reviewSummary,
            intelligenceDrivers: item.intelligenceDrivers,
            intelligenceChannels: item.intelligenceChannels,
            urgency: item.urgency,
            priceChangePercent: item.priceChangePercent,
            targetFitLabel: item.targetFitLabel,
            speedLabel: item.speedLabel,
            capitalFitLabel: item.capitalFitLabel,
            dataQualityLabel: item.dataQualityLabel,
            analysisTimestamp: item.analysisTimestamp,
            dataTimestamp: item.dataTimestamp,
            lastRefreshTimestamp: item.lastRefreshTimestamp ?? item.analysisTimestamp,
            brokerName: item.brokerName,
            orderState: OrderExecutionState(rawValue: item.orderStateRaw) ?? .ready,
            submittedPrice: item.submittedPrice,
            submittedShares: item.submittedShares,
            decisionBias: WealthDecisionBias(rawValue: item.decisionBiasRaw) ?? .hold,
            aggressionMode: WealthAggressionMode(rawValue: item.aggressionModeRaw) ?? .moderate,
            marketRegime: WealthMarketRegime(rawValue: item.marketRegimeRaw) ?? .balanced,
            targetPressureLabel: item.targetPressureLabel,
            capitalDisciplineLabel: item.capitalDisciplineLabel,
            allocationPercent: item.allocationPercent,
            positionSizePercent: item.positionSizePercent,
            conviction: WealthConvictionLevel(rawValue: item.convictionRaw) ?? .watch,
            permission: WealthPermissionState(rawValue: item.permissionRaw) ?? .wait,
            rotationBias: WealthRotationBias(rawValue: item.rotationBiasRaw) ?? .keep,
            hungerMode: WealthHungerMode(rawValue: item.hungerModeRaw) ?? .stalk,
            executionStyle: WealthExecutionStyle(rawValue: item.executionStyleRaw) ?? .wait,
            commandText: item.commandText,
            priorityScore: item.priorityScore,
            targetDirective: item.targetDirective,
            targetCoveragePercent: item.targetCoveragePercent,
            sourceReliabilityScore: item.sourceReliabilityScore,
            shareReliabilityScore: item.shareReliabilityScore,
            optionsFlowStrength: item.optionsFlowStrength,
            darkPoolStrength: item.darkPoolStrength,
            insiderStrength: item.insiderStrength,
            filingStrength: item.filingStrength,
            earningsEventRisk: item.earningsEventRisk,
            macroEventRisk: item.macroEventRisk,
            trustState: WealthTrustState(rawValue: item.trustStateRaw) ?? .usable,
            trustReason: item.trustReason,
            buyReason: item.buyReason,
            rotationReason: item.rotationReason,
            warningReason: item.warningReason,
            advancedSignal: .neutral,
            previousAiScore: nil,
            previousConfidence: nil
        )
    }
}
