import Foundation

enum WealthActivityAdmissionDecision {
    case submitImmediate
    case submitQueued
    case queue
    case reject(String)
}

enum WealthOrderRestrictionRules {
    static func meetsRebuyGate(
        opportunity: Opportunity,
        buyCooldown: (until: Date, reason: String)?,
        lastSoldPrice: Double?,
        rebuyThresholdMultiplier: Double
    ) -> Bool {
        if buyCooldown != nil {
            return false
        }

        guard let lastSoldPrice else {
            return true
        }

        return opportunity.submittedPrice >= lastSoldPrice * rebuyThresholdMultiplier
    }

    static func activityAdmissionDecision(
        opportunity: Opportunity,
        aiLive: WealthAILiveResult?,
        allowNewOrders: Bool,
        spendableCash: Double,
        passesRebuyGate: Bool,
        hasExistingQueued: Bool
    ) -> WealthActivityAdmissionDecision {
        if let aiLive, !aiLive.allowsActivityPromotion {
            return .reject("AI Live no longer promotes this card")
        }
        if opportunity.rank <= 0 {
            return .reject("Market rank is missing")
        }
        if !opportunity.hasFreshPromotionRefresh {
            return .reject("latest refresh is too old")
        }
        if !passesRebuyGate {
            return .reject("rebuy protection is active")
        }
        if let readinessReason = opportunity.executionReadiness.reason {
            return .reject(readinessReason)
        }
        if opportunity.dataQualityLabel.uppercased() == "STALE" {
            return .reject("the live data is stale")
        }
        if opportunity.earningsEventRisk >= 70 || opportunity.macroEventRisk >= 75 {
            return .reject("event risk spiked too high")
        }
        if !allowNewOrders {
            return .reject("new orders are disabled")
        }
        if opportunity.trueCost > spendableCash {
            return .reject("not enough spendable cash")
        }

        if hasExistingQueued && canSubmitBuy(opportunity: opportunity) {
            return .submitQueued
        }
        if canSubmitBuy(opportunity: opportunity) {
            return .submitImmediate
        }
        if canQueueBuy(opportunity: opportunity) {
            return .queue
        }

        return .reject("the market session is not ready for execution")
    }

    private static func canSubmitBuy(opportunity: Opportunity) -> Bool {
        opportunity.isExecutionEligible &&
        opportunity.sessionState.canTradeNow
    }

    private static func canQueueBuy(opportunity: Opportunity) -> Bool {
        opportunity.canQueueForOpen
    }
}
