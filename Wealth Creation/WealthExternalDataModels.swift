import Foundation
import SwiftUI

struct WealthProviderBias: Hashable {
    let qualityLift: Double
    let confidenceLift: Double
    let rewardLift: Double
    let riskPenalty: Double

    static let neutral = WealthProviderBias(qualityLift: 0, confidenceLift: 0, rewardLift: 0, riskPenalty: 0)
}

struct WealthProviderSource: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let status: String
    let detail: String
    let tint: Color
}
