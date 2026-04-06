import Foundation

// MARK: - WealthAILivePromotionReason

enum WealthAILivePromotionReason: String, CustomStringConvertible {
    case topTierScore   = "topTierScore"
    case momentumSurge  = "momentumSurge"
    case riskCleared    = "riskCleared"

    var description: String { rawValue }
}

// MARK: - WealthAILivePromotion

struct WealthAILivePromotion: Equatable {
    let opportunity:      Opportunity
    let reason:           WealthAILivePromotionReason
    let scoreAtPromotion: Double
    let rankAtPromotion:  Int
    let promotedAt:       Date
}

// MARK: - WealthAILiveIntakeCondition

struct WealthAILiveIntakeCondition: Equatable {
    let name:   String
    let passed: Bool
    let detail: String?
}

// MARK: - WealthAILiveCoordinator+Models

extension WealthAILiveCoordinator {

    func intakeConditions(for opportunity: Opportunity) -> [WealthAILiveIntakeCondition] {
        [
            WealthAILiveIntakeCondition(
                name:   "Data not stale",
                passed: !opportunity.isDataStale,
                detail: opportunity.isDataStale ? "STALE" : "FRESH"
            ),
            WealthAILiveIntakeCondition(
                name:   "Anomaly stable",
                passed: opportunity.isAnomalyStable,
                detail: opportunity.isAnomalyStable ? "STABLE" : "UNSTABLE"
            ),
            WealthAILiveIntakeCondition(
                name:   "Earnings risk < \(SafeguardThreshold.earningsRisk)",
                passed: opportunity.earningsRisk < SafeguardThreshold.earningsRisk,
                detail: "earningsRisk=\(opportunity.earningsRisk)"
            ),
            WealthAILiveIntakeCondition(
                name:   "Macro risk < \(SafeguardThreshold.macroRisk)",
                passed: opportunity.macroRisk < SafeguardThreshold.macroRisk,
                detail: "macroRisk=\(opportunity.macroRisk)"
            ),
        ]
    }
}
