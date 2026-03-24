import SwiftUI

extension WealthEngineStore {
    static func cappedShareCount(proposedShares: Int, price: Double, buyingPower: Double) -> Int {
        guard price > 0, buyingPower > 0 else { return 0 }

        var shares = max(1, proposedShares)
        while shares > 0 {
            let subtotal = Double(shares) * price
            let totalCost = subtotal + WealthScoringEngine.feeEstimate(for: subtotal)
            if totalCost <= buyingPower {
                return shares
            }
            shares -= 1
        }

        return 0
    }

    static func sizedShares(maxAffordableShares: Int, allocationPercent: Int, decision: WealthDecisionBias) -> Int {
        guard maxAffordableShares > 0, allocationPercent > 0, decision != .avoid else { return 0 }

        let ratio = Double(allocationPercent) / 100
        return max(1, Int(floor(Double(maxAffordableShares) * ratio)))
    }

    static func convictionLevel(for score: Int, confidence: Int, decision: WealthDecisionBias) -> WealthConvictionLevel {
        guard decision != .avoid else { return .weak }
        if score <= 12 && confidence >= 85 { return .top }
        if score <= 25 && confidence >= 70 { return .strong }
        return .watch
    }
}
