import Foundation

struct WealthLiveQuote: Hashable {
    let price: Double
    let changePercent: Double
    let dataAge: TimeInterval
}

enum WealthLivePricingEngine {
    static func quote(
        for blueprint: OpportunityBlueprint,
        previous: Opportunity?,
        refreshTime: Date,
        sessionOpen: Bool
    ) -> WealthLiveQuote {
        let previousPrice = previous?.price ?? blueprint.price
        let minuteBucket = max(1, Int(refreshTime.timeIntervalSince1970 / 60))

        let symbolDrift = normalizedHash("\(blueprint.symbol)-\(minuteBucket)") - 0.5
        let marketDrift = normalizedHash("\(blueprint.market)-\(minuteBucket / 3)") - 0.5
        let sectorDrift = normalizedHash("\(blueprint.sector)-\(minuteBucket / 5)") - 0.5

        let liquidityWeight = min(1.0, max(0.18, log10(max(blueprint.averageDailyDollarVolume, 10_000)) / 10.0))
        let volatilityBias = max(0.15, blueprint.risk / 100.0)
        let momentumBias = blueprint.priceChangePercent / 100.0
        let intradayRange = (0.0009 + (volatilityBias * 0.010)) * (sessionOpen ? 1.0 : 0.22)

        let stepMove =
            (symbolDrift * intradayRange) +
            (marketDrift * intradayRange * 0.55) +
            (sectorDrift * intradayRange * 0.35) +
            (momentumBias * 0.08 * (sessionOpen ? 1.0 : 0.35))

        let dampedMove = stepMove * max(0.35, liquidityWeight)
        let rawPrice = previousPrice * (1 + dampedMove)
        let boundedPrice = min(maxPrice(for: blueprint.price), max(minPrice(for: blueprint.price), rawPrice))
        let roundedPrice = roundedPriceForDisplay(boundedPrice)

        return WealthLiveQuote(
            price: roundedPrice,
            changePercent: ((roundedPrice / blueprint.price) - 1) * 100,
            dataAge: sessionOpen ? 0 : min(blueprint.dataAge, 15 * 60)
        )
    }

    private static func normalizedHash(_ value: String) -> Double {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Double(hash % 10_000) / 10_000.0
    }

    private static func minPrice(for anchor: Double) -> Double {
        max(0.01, anchor * 0.55)
    }

    private static func maxPrice(for anchor: Double) -> Double {
        max(minPrice(for: anchor) + 0.01, anchor * 1.45)
    }

    private static func roundedPriceForDisplay(_ price: Double) -> Double {
        switch price {
        case ..<1:
            return (price * 10_000).rounded() / 10_000
        case ..<500:
            return (price * 100).rounded() / 100
        default:
            return (price * 10).rounded() / 10
        }
    }
}
