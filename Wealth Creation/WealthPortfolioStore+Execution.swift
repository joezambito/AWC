import Foundation

extension WealthPortfolioStore {
    var rebuyThresholdMultiplier: Double { 1.05 }
    var failedBuyCooldown: TimeInterval { 6 * 60 * 60 }
    var fastSellCooldown: TimeInterval { 12 * 60 * 60 }

    func shouldTriggerSell(_ holding: Holding, protection: WealthProtectionSettingsStore) -> Bool {
        WealthProtectionExitRules.shouldTriggerSell(holding: holding, protection: protection)
    }

    func meetsRebuyGate(_ opportunity: Opportunity) -> Bool {
        clearExpiredBuyCooldown(for: opportunity.symbol, market: opportunity.market)
        return WealthOrderRestrictionRules.meetsRebuyGate(
            opportunity: opportunity,
            buyCooldown: buyCooldown(for: opportunity.symbol, market: opportunity.market),
            lastSoldPrice: lastSoldPrice(for: opportunity.symbol, market: opportunity.market),
            rebuyThresholdMultiplier: rebuyThresholdMultiplier
        )
    }

    static func completedBuySnapshot(from holding: Holding, completedAt: Date) -> Opportunity {
        WealthPortfolioExecutionSnapshots.completedBuySnapshot(from: holding, completedAt: completedAt)
    }

    static func completedSellSnapshot(from holding: Holding, completedAt: Date) -> Opportunity {
        WealthPortfolioExecutionSnapshots.completedSellSnapshot(from: holding, completedAt: completedAt)
    }
}
