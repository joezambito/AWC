import Foundation

extension WealthAdvancedBrainEngine {
    @MainActor
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
        if WealthBrainToggleStore.shared.isEnabled(title: "Moving Averages 15 / 20 / 30 / 50 / 100 / 200") {
            score += Int(round(movingAverageBias(
                technical: blueprint.technical,
                probability: blueprint.probability,
                positiveTape: max(0, blueprint.priceChangePercent)
            )))
        }
        if WealthBrainToggleStore.shared.isEnabled(title: "Cross-Asset Relative Strength") {
            let sourceText = ([blueprint.sourceTrigger] + blueprint.intelligenceDrivers + blueprint.intelligenceChannels)
                .joined(separator: " ")
            score += Int(round(crossAssetBias(
                sectorFlow: blueprint.sectorFlow,
                market: blueprint.market,
                sourceText: sourceText
            )))
        }
        if WealthBrainModuleRegistry.isEnabled(title: "Trend Detection") {
            score += explicitTrendDetectionBias(for: blueprint, regime: regime)
        }

        return score
    }

    @MainActor
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
        if WealthBrainToggleStore.shared.isEnabled(title: "Relative Strength Index (RSI)") {
            score += Int(round(approximateRSIBias(
                technical: blueprint.technical,
                priceChangePercent: blueprint.priceChangePercent,
                catalyst: blueprint.catalyst
            )))
        }
        if WealthBrainToggleStore.shared.isEnabled(title: "Stochastic Oscillator") {
            score += Int(round(approximateStochasticBias(
                technical: blueprint.technical,
                priceChangePercent: blueprint.priceChangePercent,
                probability: blueprint.probability
            )))
        }

        return score
    }

    @MainActor
    static func patternScore(for blueprint: OpportunityBlueprint, textBundle: WealthAdvancedBrainTextBundle) -> Int {
        let text = textBundle.sourceUpper

        var score = 0
        if text.contains("BREAKOUT") || text.contains("TREND CONTINUATION") { score += 5 }
        if text.contains("BASE") || text.contains("RECOVERY") || text.contains("REVERSAL") { score += 3 }
        if text.contains("DOUBLE TOP") || text.contains("FAILED HIGH") || text.contains("EXHAUSTION") { score -= 5 }
        if text.contains("INSUFFICIENT DATA") || text.contains("UNKNOWN") { score -= 3 }
        if WealthBrainToggleStore.shared.isEnabled(title: "Volume / Price Discrepancies") {
            score += Int(round(volumeDiscrepancyBias(
                priceChangePercent: blueprint.priceChangePercent,
                combinedUpperText: textBundle.combinedUpper
            )))
        }
        return score
    }

    static func explicitTrendDetectionBias(
        for blueprint: OpportunityBlueprint,
        regime: WealthMarketRegime
    ) -> Int {
        let text = (
            [blueprint.sourceTrigger, blueprint.sourceSummary, blueprint.reviewSummary] +
            blueprint.intelligenceDrivers +
            blueprint.intelligenceChannels
        )
        .joined(separator: " ")
        .uppercased()

        var score = 0
        if text.contains("TREND") || text.contains("MOMENTUM") || text.contains("LEADER") {
            score += 1
        }
        if text.contains("ROTATION") || text.contains("FOLLOW-THROUGH") || text.contains("CONTINUATION") {
            score += 1
        }
        if blueprint.priceChangePercent >= 1.0 && blueprint.sectorFlow >= 60 {
            score += 1
        }
        if blueprint.priceChangePercent <= -2.5 && blueprint.sectorFlow <= 45 {
            score -= 2
        }
        if regime == .riskOn && blueprint.timeWindow == "HOURS" {
            score += 1
        }
        if regime == .defensive && blueprint.timeWindow == "HOURS" {
            score -= 1
        }

        return max(-2, min(3, score))
    }
}
