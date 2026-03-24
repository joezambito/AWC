import Foundation

extension WealthScoringEngine {
    static func confidencePenalty(for confidence: Int) -> Int {
        switch confidence {
        case 80...: return 0
        case 70...79: return 10
        case 60...69: return 20
        case 50...59: return 30
        default: return 40
        }
    }

    static func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }

    static func clampInt(_ value: Int, min minimum: Int, max maximum: Int) -> Int {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}
