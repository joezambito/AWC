import Foundation

extension WealthAdvancedBrainEngine {
    static func approximateRSIBias(technical: Double, priceChangePercent: Double, catalyst: Double) -> Double {
        if technical > 86 && priceChangePercent > 2.4 {
            return catalyst > 75 ? -1 : -6
        }
        if technical < 52 && priceChangePercent < -1.8 {
            return catalyst > 68 ? 5 : 2
        }
        if technical >= 68 && priceChangePercent > 0 {
            return 3
        }
        return 0
    }

    static func approximateStochasticBias(technical: Double, priceChangePercent: Double, probability: Double) -> Double {
        if technical > 82 && probability > 72 && priceChangePercent > 0.8 {
            return 4
        }
        if technical < 45 && priceChangePercent < -2.0 {
            return -2
        }
        if priceChangePercent > 3.0 {
            return -1
        }
        return 1
    }

    static func movingAverageBias(technical: Double, probability: Double, positiveTape: Double) -> Double {
        if technical >= 76 && probability >= 70 && positiveTape > 0.25 { return 5 }
        if technical <= 46 && positiveTape < 0.2 { return -4 }
        return technical >= 60 ? 2 : 0
    }

    static func crossAssetBias(sectorFlow: Double, market: String, sourceText: String) -> Double {
        var score = max(-3.0, min(5.0, (sectorFlow - 50) * 0.10))
        if market.uppercased().contains("US") || sourceText.contains("INDEX LEADER") { score += 1.5 }
        return score
    }

    private static func tokenMatch(_ uppercasedText: String, _ needles: [String]) -> Bool {
        needles.contains { uppercasedText.contains($0) }
    }

    static func volumeDiscrepancyBias(priceChangePercent: Double, combinedUpperText: String) -> Double {
        if abs(priceChangePercent) >= 3.2 && tokenMatch(combinedUpperText, ["LOW VOLUME", "THIN", "FADE"]) {
            return -5
        }
        if tokenMatch(combinedUpperText, ["ACCUMULATION", "EXPANDING VOLUME", "CONFIRMED BREAKOUT"]) {
            return 4
        }
        return 0
    }

    static func volatilityPenalty(risk: Double, priceChangePercent: Double, timeWindow: String) -> Double {
        var penalty = 0.0
        if risk >= 55 { penalty += 5 }
        if abs(priceChangePercent) >= 4.5 { penalty += 3 }
        if timeWindow == "HOURS" && abs(priceChangePercent) >= 3 { penalty += 2 }
        return penalty
    }

    private static func patternBias(from text: String, intelligenceText: String, isEnabled: (String) -> Bool) -> Int {
        let sourceText = text.uppercased()
        let combinedText = (text + " " + intelligenceText).uppercased()
        var score = 0
        if tokenMatch(sourceText, ["BREAKOUT", "TREND CONTINUATION", "SECTOR ROTATION"]) { score += 5 }
        if tokenMatch(sourceText, ["TECHNICAL BREAKOUT", "MOMENTUM BREAKOUT"]) { score += 3 }
        if isEnabled("Triangles") && tokenMatch(combinedText, ["TRIANGLE", "PENNANT", "COMPRESSION BREAK"]) { score += 5 }
        if isEnabled("Double Bottoms") && tokenMatch(combinedText, ["DOUBLE BOTTOM", "BASE RECOVERY", "UNDERCUT RECOVERY"]) { score += 5 }
        if isEnabled("Head and Shoulders") && tokenMatch(combinedText, ["HEAD AND SHOULDERS INVERSE"]) { score += 4 }
        if isEnabled("Topping Pattern Detection") && tokenMatch(combinedText, ["TOPPING", "EXHAUSTION", "BLOW-OFF"]) { score -= 6 }
        if isEnabled("Double Tops") && tokenMatch(combinedText, ["DOUBLE TOP", "FAILED HIGH"]) { score -= 6 }
        if isEnabled("Head and Shoulders") && tokenMatch(combinedText, ["HEAD AND SHOULDERS", "NECKLINE BREAK"]) { score -= 7 }
        if tokenMatch(sourceText, ["INSUFFICIENT DATA", "UNKNOWN"]) { score -= 4 }
        return score
    }

    private static func smartMoneyBias(institutional: Double, alternative: Double, sourceText: String, intelligenceText: String) -> Int {
        let sourceUpper = sourceText.uppercased()
        let intelUpper = intelligenceText.uppercased()
        var score = Int(round((institutional * 0.08) + (alternative * 0.05) - 8))
        if tokenMatch(sourceUpper, ["SMART MONEY", "INSTITUTIONAL"]) { score += 4 }
        if tokenMatch(intelUpper, ["DARK POOL", "OPTIONS", "13F", "INSIDER"]) { score += 6 }
        if tokenMatch(intelUpper, ["TRANSCRIPT", "RESEARCH"]) { score += 2 }
        return score
    }

    private static func smartMoneyBias(
        institutional: Double,
        alternative: Double,
        optionsFlowStrength: Double,
        darkPoolStrength: Double,
        insiderStrength: Double,
        filingStrength: Double,
        sourceText: String,
        intelligenceText: String,
        isEnabled: (String) -> Bool
    ) -> Int {
        let sourceUpper = sourceText.uppercased()
        let intelUpper = intelligenceText.uppercased()
        let combinedText = sourceUpper + " " + intelUpper

        let structuralLift =
            (isEnabled("Options Flow") ? (optionsFlowStrength * 0.06) : 0)
            + (isEnabled("Dark Pool Data") ? (darkPoolStrength * 0.07) : 0)
            + (isEnabled("Insider Monitoring") ? (insiderStrength * 0.05) : 0)
            + (isEnabled("13F Filing Analysis") ? (filingStrength * 0.05) : 0)

        var score = smartMoneyBias(
            institutional: institutional,
            alternative: alternative + structuralLift,
            sourceText: sourceUpper,
            intelligenceText: intelUpper
        ) + Int(round(structuralLift * 0.12))

        if isEnabled("Predicting Active Fund Trades") && tokenMatch(combinedText, ["SECTOR ROTATION", "FUND FLOW", "ACTIVE FUND"]) {
            score += 4
        }
        if isEnabled("Smart Money Divergence") {
            if tokenMatch(intelUpper, ["DARK POOL", "OPTIONS"]) && tokenMatch(sourceUpper, ["SELL-OFF", "PULLBACK"]) {
                score += 3
            }
            if tokenMatch(intelUpper, ["DISTRIBUTION"]) && tokenMatch(sourceUpper, ["BREAKOUT", "CHASE"]) {
                score -= 5
            }
        }

        return score
    }
}
