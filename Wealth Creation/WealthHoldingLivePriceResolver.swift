import Foundation

enum WealthHoldingLivePriceResolver {
    static func resolvedCurrentPrice(
        currentPrice: Double,
        livePrice: Double,
        averagePrice: Double
    ) -> Double {
        if livePrice > 0 {
            return livePrice
        }

        if currentPrice > 0 {
            return currentPrice
        }

        if averagePrice > 0 {
            return averagePrice
        }

        return 0
    }
}
