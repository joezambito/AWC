import Foundation
import SwiftUI

enum WealthAILiveDecision: String, Hashable, Codable {
    case promote
    case returnToMarket
    case replaceExisting
    case reject
}

enum WealthActivityReturnState: String, Hashable, Codable {
    case activityRejected = "ACTIVITY REJECTED"
    case activityCancelledPendingBuy = "ACTIVITY CANCELLED PENDING BUY"
    case activityCancelledPendingSell = "ACTIVITY CANCELLED PENDING SELL"
}

struct WealthActivityRefusalHandoff: Hashable, Identifiable, Codable {
    let key: String
    let symbol: String
    let market: String
    let state: WealthActivityReturnState
    let reason: String
    let timestamp: Date

    var id: String { key }
}

struct WealthAILiveResult: Hashable, Identifiable, Codable {
    let key: String
    let symbol: String
    let market: String
    let aiLiveDecision: WealthAILiveDecision
    let reason: String
    let activityReturnState: WealthActivityReturnState?
    let activityReturnReason: String?

    var id: String { key }

    var aiLiveColor: Color {
        switch aiLiveDecision {
        case .promote, .replaceExisting:
            return WealthTheme.green
        case .returnToMarket:
            return WealthTheme.blue
        case .reject:
            return WealthTheme.red
        }
    }

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

    func withActivityReturn(_ handoff: WealthActivityRefusalHandoff?) -> WealthAILiveResult {
        WealthAILiveResult(
            key: key,
            symbol: symbol,
            market: market,
            aiLiveDecision: aiLiveDecision,
            reason: reason,
            activityReturnState: handoff?.state,
            activityReturnReason: handoff?.reason
        )
    }
}

struct WealthAILiveEvaluation {
    let resultsByKey: [String: WealthAILiveResult]
    let promotedKeys: Set<String>
    let replacedActivityKeys: Set<String>
    let replacementByNewKey: [String: String]
    let replacedByOldKey: [String: String]
}
