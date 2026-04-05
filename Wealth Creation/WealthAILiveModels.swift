import Foundation

// MARK: - WealthAILiveDecision

enum WealthAILiveDecision: String, Codable, Equatable {
    case promote
    case reject
    case replaceExisting
    case hold
}

// MARK: - WealthAILiveResult

struct WealthAILiveResult: Codable, Equatable {
    let key: String
    let symbol: String
    let market: String
    let aiLiveDecision: WealthAILiveDecision
    let reason: String
    let activityReturnState: WealthActivityRefusalState?
    let activityReturnReason: String?

    var allowsActivityPromotion: Bool {
        aiLiveDecision == .promote || aiLiveDecision == .replaceExisting
    }

    func with(decision: WealthAILiveDecision, reason: String) -> WealthAILiveResult {
        WealthAILiveResult(
            key: key,
            symbol: symbol,
            market: market,
            aiLiveDecision: decision,
            reason: reason,
            activityReturnState: activityReturnState,
            activityReturnReason: activityReturnReason
        )
    }
}

// MARK: - WealthAILiveEvaluation

struct WealthAILiveEvaluation {
    let resultsByKey: [String: WealthAILiveResult]
    let promotedKeys: Set<String>
    let replacedActivityKeys: Set<String>
    let replacementByNewKey: [String: String]
    let replacedByOldKey: [String: String]
}

// MARK: - WealthActivityRefusalState

enum WealthActivityRefusalState: String, Codable, Equatable {
    case cancelled
    case expired
    case rejected
    case superseded
}

// MARK: - WealthActivityRefusalHandoff

struct WealthActivityRefusalHandoff {
    let state: WealthActivityRefusalState
    let reason: String
    let symbol: String
    let refusedAt: Date
}

// MARK: - WealthOpportunityLaneRules

enum WealthOpportunityLaneRules {
    /// Returns the canonical lane key for an opportunity (symbol-based).
    static func laneKey(_ opportunity: Opportunity) -> String {
        opportunity.symbol.uppercased()
    }

    /// Returns the canonical lane key for a holding (symbol-based).
    static func laneKey(_ holding: Holding) -> String {
        holding.symbol.uppercased()
    }
}
