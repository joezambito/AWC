import Foundation

enum WealthProtectionExitRules {
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
