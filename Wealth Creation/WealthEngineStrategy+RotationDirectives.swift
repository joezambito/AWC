import SwiftUI

extension WealthEngineStore {
    static func rotationSignal(
        for blueprint: OpportunityBlueprint,
        score: Int,
        confidence: Int,
        decision: WealthDecisionBias,
        holdings: [Holding],
        settings: WealthBehaviorSettingsStore
    ) -> (bias: WealthRotationBias, reason: String) {
        guard decision != .avoid else {
            return (.block, "This setup is not strong enough to replace current capital.")
        }

        if let owned = holdings.first(where: { $0.symbol == blueprint.symbol }) {
            if score <= max(owned.aiScore - 3, 12), confidence >= owned.confidence {
                return (.add, "The AI already owns \(blueprint.symbol) and the fresh signal still justifies adding with controlled size.")
            }
            return (.keep, "The AI already owns \(blueprint.symbol), so it keeps it on watch instead of forcing a bigger rotation.")
        }

        let sectorHoldings = holdings.filter { $0.sector == blueprint.sector }
        if let weakestSectorHolding = sectorHoldings.max(by: { $0.aiScore < $1.aiScore }) {
            let edge = weakestSectorHolding.aiScore - score
            if edge >= settings.rotateEdge && confidence >= weakestSectorHolding.confidence {
                return (.rotate, "\(blueprint.symbol) is beating \(weakestSectorHolding.symbol) by \(edge) score points, so the AI can rotate rather than over-stack the sector.")
            }
            if sectorHoldings.count >= 2 {
                return (.block, "Sector exposure is already heavy, so the AI will not add another \(blueprint.sector.lowercased()) name yet.")
            }
        }

        return (.add, "\(blueprint.symbol) is a fresh short-term candidate and fits as new capital, not a forced replacement.")
    }
}
