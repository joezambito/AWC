import Foundation

extension Opportunity {
    var totalEntryCost: Double {
        let shareCount = max(submittedShares, recommendedShares)
        guard shareCount > 0 else { return 0 }
        let entryPrice = submittedPrice > 0 ? submittedPrice : price
        return (entryPrice * Double(shareCount)) + brokerFee
    }

    var expectedNetPercent: Double {
        guard totalEntryCost > 0 else { return 0 }
        return (expectedProfit / totalEntryCost) * 100
    }

    var isQueuedForActivity: Bool {
        orderState == .ready || orderState == .submitted || orderState == .pending || orderState == .partial
    }

    var usesLiveSessionGate: Bool {
        permission != .blocked && orderState != .filled
    }
}
