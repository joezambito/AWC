import Foundation

enum WealthProtectionExitRules {
    static func hasValidShieldBoundary(
        entryPrice: Double,
        shares: Int,
        totalCost: Double,
        protection: WealthProtectionSettingsStore
    ) -> Bool {
        guard shares > 0, entryPrice > 0, totalCost > 0 else { return false }

        let shieldPercent = max(0, protection.shieldPercent)
        guard shieldPercent > 0 else { return false }

        let targetReturnPercent = -shieldPercent
        let targetNetValue = max(0, totalCost * (1 + (targetReturnPercent / 100)))
        let percentageGrossValue = targetNetValue / (1 - 0.00047)
        let flatFeeGrossValue = targetNetValue + 0.50
        let grossValue = max(percentageGrossValue, flatFeeGrossValue)
        let shieldExitPrice = max(0, grossValue / Double(shares))

        guard shieldExitPrice > 0 else { return false }
        return shieldExitPrice < entryPrice
    }

    static func shouldTriggerSell(
        holding: Holding,
        protection: WealthProtectionSettingsStore
    ) -> Bool {
        let shieldTriggered = holding.netReturnPercent <= (-protection.shieldPercent)
        if shieldTriggered {
            return true
        }

        let gainTargetHit = holding.netReturnPercent >= protection.profitTargetValue
        guard gainTargetHit else {
            return false
        }

        guard protection.surgeEnabled else {
            return true
        }

        let surgeLockedTarget = protection.profitTargetValue + max(0, protection.surgeOverridePercent)
        return holding.netReturnPercent >= surgeLockedTarget
    }
}
