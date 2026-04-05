import Foundation

// MARK: - WealthAILiveCoordinator+Models
//
// Value types used by the AI Live coordinator.

// MARK: - WealthAILivePromotionReason

/// Describes why an opportunity was promoted to AI Live.
enum WealthAILivePromotionReason: String, CustomStringConvertible {
    case topTierScore   = "topTierScore"
    case momentumSurge  = "momentumSurge"
    case riskCleared    = "riskCleared"

    var description: String { rawValue }
}

// MARK: - WealthAILivePromotion

/// A record of a single AI Live promotion decision.
struct WealthAILivePromotion: Equatable {

    /// The opportunity that was promoted.
    let opportunity: Opportunity

    /// Primary reason for promotion.
    let reason: WealthAILivePromotionReason

    /// AI score at the time of promotion.
    let scoreAtPromotion: Double

    /// Market rank at the time of promotion.
    let rankAtPromotion: Int

    /// When the promotion was recorded.
    let promotedAt: Date
}

// MARK: - WealthAILiveIntakeCondition

/// A single intake condition checked during AI Live evaluation.
struct WealthAILiveIntakeCondition: Equatable {

    /// Human-readable name of the condition.
    let name: String

    /// Whether this condition passed for a given card.
    let passed: Bool

    /// Optional detail message (e.g. measured value vs threshold).
    let detail: String?
}
