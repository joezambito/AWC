import Foundation

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

    static func canSubmitImmediateBuy(
        opportunity: Opportunity,
        allowNewOrders: Bool,
        spendableCash: Double,
        passesRebuyGate: Bool
    ) -> Bool {
        allowNewOrders &&
        opportunity.isGreenBuyReady &&
        opportunity.recommendedShares > 0 &&
        opportunity.sessionState.canTradeNow &&
        passesRebuyGate &&
        opportunity.trueCost > 0 &&
        opportunity.trueCost <= spendableCash
    }

    static func canSubmitQueuedBuy(
        opportunity: Opportunity,
        allowNewOrders: Bool,
        spendableCash: Double,
        passesRebuyGate: Bool
    ) -> Bool {
        allowNewOrders &&
        opportunity.isGreenBuyReady &&
        opportunity.recommendedShares > 0 &&
        opportunity.sessionState.canTradeNow &&
        passesRebuyGate &&
        opportunity.trueCost > 0 &&
        opportunity.trueCost <= spendableCash
    }

    static func canQueueBuy(
        opportunity: Opportunity,
        allowNewOrders: Bool,
        spendableCash: Double,
        passesRebuyGate: Bool
    ) -> Bool {
        allowNewOrders &&
        opportunity.canQueueForOpen &&
        passesRebuyGate &&
        opportunity.trueCost > 0 &&
        opportunity.trueCost <= spendableCash
    }
}
