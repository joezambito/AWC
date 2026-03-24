import Foundation

extension WealthScoringEngine {
    static func smartMoneyBonus(for blueprint: OpportunityBlueprint) -> Double {
        let direct =
            (blueprint.optionsFlowStrength * 0.10)
            + (blueprint.darkPoolStrength * 0.12)
            + (blueprint.insiderStrength * 0.08)
            + (blueprint.filingStrength * 0.07)
        let text = ([blueprint.sourceTrigger] + blueprint.intelligenceDrivers + blueprint.intelligenceChannels)
            .joined(separator: " ")
            .uppercased()

        var textLift = 0.0
        if text.contains("OPTIONS") { textLift += 4.5 }
        if text.contains("DARK POOL") { textLift += 5.5 }
        if text.contains("13F") { textLift += 4.0 }
        if text.contains("INSIDER") { textLift += 3.5 }
        return direct + textLift
    }

    static func liquidityQuality(for blueprint: OpportunityBlueprint) -> Double {
        if blueprint.averageDailyDollarVolume > 0 {
            return clamp(log10(max(blueprint.averageDailyDollarVolume, 1)) * 12, min: 20, max: 100)
        }

        var quality = 58.0
        let origin = blueprint.dataOrigin.uppercased()
        let fit = blueprint.capitalFitLabel.uppercased()

        if fit.contains("EASY") { quality += 12 }
        if fit.contains("GOOD") { quality += 6 }
        if fit.contains("HEAVY") { quality -= 8 }
        if fit.contains("POOR") { quality -= 18 }
        if origin.contains("THIN FEED") { quality -= 24 }
        if origin.contains("PRICE/VOLUME FEED") { quality += 8 }
        if origin.contains("SMART MONEY") { quality += 4 }
        if blueprint.market == "CRYPTO" { quality -= 6 }
        if blueprint.market == "COMMODITY" { quality -= 4 }

        return clamp(quality, min: 18, max: 100)
    }

    static func spreadPenalty(for blueprint: OpportunityBlueprint) -> Double {
        let spread = blueprint.spreadBps > 0 ? blueprint.spreadBps : estimatedSpreadBps(for: blueprint)
        switch spread {
        case ...15: return 0
        case ...30: return 3
        case ...60: return 7
        default: return 13
        }
    }

    static func slippagePenalty(for blueprint: OpportunityBlueprint) -> Double {
        let slippage = blueprint.slippageRisk > 0 ? blueprint.slippageRisk : estimatedSlippageRisk(for: blueprint)
        switch slippage {
        case ...20: return 0
        case ...40: return 3
        case ...65: return 8
        default: return 14
        }
    }

    static func calendarPenalty(for blueprint: OpportunityBlueprint) -> Double {
        let earnings = blueprint.earningsEventRisk > 0 ? blueprint.earningsEventRisk : inferredEarningsRisk(for: blueprint)
        let macro = blueprint.macroEventRisk > 0 ? blueprint.macroEventRisk : inferredMacroRisk(for: blueprint)
        return max(0, (earnings * 0.08) + (macro * 0.07) - 3)
    }

    static func sectorExposurePenalty(for blueprint: OpportunityBlueprint, holdings: [Holding]) -> Double {
        let sectorCount = holdings.filter { $0.sector == blueprint.sector }.count
        return sectorCount == 0 ? 0 : Double(sectorCount) * 4.5
    }

    private static func estimatedSpreadBps(for blueprint: OpportunityBlueprint) -> Double {
        var spread = 18.0
        if blueprint.price < 20 { spread += 12 }
        if blueprint.capitalFitLabel.uppercased().contains("HEAVY") { spread += 18 }
        if blueprint.capitalFitLabel.uppercased().contains("POOR") { spread += 28 }
        if blueprint.speedLabel.uppercased().contains("FAST") { spread += 10 }
        if blueprint.dataOrigin.uppercased().contains("THIN FEED") { spread += 30 }
        if blueprint.market == "CRYPTO" { spread += 20 }
        return spread
    }

    private static func estimatedSlippageRisk(for blueprint: OpportunityBlueprint) -> Double {
        var risk = blueprint.risk * 0.45
        if blueprint.urgency.uppercased().contains("NOW") { risk += 14 }
        if blueprint.speedLabel.uppercased().contains("FAST") { risk += 10 }
        if blueprint.capitalFitLabel.uppercased().contains("HEAVY") { risk += 14 }
        if blueprint.dataOrigin.uppercased().contains("THIN FEED") { risk += 20 }
        return risk
    }

    private static func inferredEarningsRisk(for blueprint: OpportunityBlueprint) -> Double {
        let text = [blueprint.sourceTrigger, blueprint.catalystBucket, blueprint.reviewSummary]
            .joined(separator: " ")
            .uppercased()
        if text.contains("EARNINGS") { return 55 }
        if text.contains("CONFERENCE") || text.contains("TRANSCRIPT") { return 20 }
        return 0
    }

    private static func inferredMacroRisk(for blueprint: OpportunityBlueprint) -> Double {
        let text = [blueprint.sourceTrigger, blueprint.catalystBucket, blueprint.dataOrigin]
            .joined(separator: " ")
            .uppercased()
        if text.contains("MACRO") { return 48 }
        if text.contains("COMMODITY") || text.contains("CRYPTO") { return 24 }
        return 0
    }
}
