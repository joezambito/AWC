import Foundation

enum WealthScoringEngine {
    static func feeEstimate(for subtotal: Double) -> Double {
        max(1.62, subtotal * 0.00709)
    }
}
