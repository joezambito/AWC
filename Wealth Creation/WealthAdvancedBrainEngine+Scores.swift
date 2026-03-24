import Foundation

extension WealthAdvancedBrainEngine {
    static func trendScore(for blueprint: OpportunityBlueprint, regime: WealthMarketRegime) -> Int {
        var score = 0

        if blueprint.technical >= 78 {
            score += 5
        } else if blueprint.technical >= 66 {
            score += 3
        } else if blueprint.technical <= 42 {
            score -= 4
        }

        if blueprint.priceChangePercent >= 2.0 {
            score += 3
        } else if blueprint.priceChangePercent <= -3.0 {
            score -= 3
        }

        if blueprint.sectorFlow >= 70 {
            score += 2
        } else if blueprint.sectorFlow <= 40 {
            score -= 2
        }

        if blueprint.probability >= 72 { score += 2 }
        if blueprint.timeWindow == "HOURS" && regime == .riskOn { score += 1 }
        if blueprint.timeWindow == "HOURS" && regime == .defensive { score -= 2 }

        return score
    }

    static func momentumScore(for blueprint: OpportunityBlueprint) -> Int {
        var score = 0

        if blueprint.priceChangePercent >= 3.0 {
            score += 4
        } else if blueprint.priceChangePercent >= 1.0 {
            score += 2
        } else if blueprint.priceChangePercent <= -4.0 {
            score -= 4
        } else if blueprint.priceChangePercent <= -1.5 {
            score -= 2
        }

        if blueprint.technical >= 74 { score += 3 }
        if blueprint.probability >= 70 { score += 2 }
        if blueprint.speedLabel.uppercased().contains("FAST") { score += 1 }
        if blueprint.dataQualityLabel.uppercased() == "STALE" { score -= 3 }

        return score
    }

    static func patternScore(for blueprint: OpportunityBlueprint) -> Int {
        let text = [
            blueprint.sourceTrigger,
            blueprint.sourceSummary,
            blueprint.reviewSummary,
            blueprint.catalystBucket
        ]
        .joined(separator: " ")
        .uppercased()

        var score = 0
        if text.contains("BREAKOUT") || text.contains("TREND CONTINUATION") { score += 5 }
        if text.contains("BASE") || text.contains("RECOVERY") || text.contains("REVERSAL") { score += 3 }
        if text.contains("DOUBLE TOP") || text.contains("FAILED HIGH") || text.contains("EXHAUSTION") { score -= 5 }
        if text.contains("INSUFFICIENT DATA") || text.contains("UNKNOWN") { score -= 3 }
        return score
    }
}
