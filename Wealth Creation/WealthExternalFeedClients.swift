import Foundation

struct WealthNormalizedExternalSignal: Hashable {
    var optionsFlowStrength: Double = 0
    var darkPoolStrength: Double = 0
    var insiderStrength: Double = 0
    var filingStrength: Double = 0
    var earningsEventRisk: Double = 0
    var macroEventRisk: Double = 0

    static let zero = WealthNormalizedExternalSignal()

    func merged(with other: WealthNormalizedExternalSignal) -> WealthNormalizedExternalSignal {
        WealthNormalizedExternalSignal(
            optionsFlowStrength: max(optionsFlowStrength, other.optionsFlowStrength),
            darkPoolStrength: max(darkPoolStrength, other.darkPoolStrength),
            insiderStrength: max(insiderStrength, other.insiderStrength),
            filingStrength: max(filingStrength, other.filingStrength),
            earningsEventRisk: max(earningsEventRisk, other.earningsEventRisk),
            macroEventRisk: max(macroEventRisk, other.macroEventRisk)
        )
    }

    func value(for kind: WealthExternalResearchKind) -> Double {
        switch kind {
        case .optionsFlow: return optionsFlowStrength
        case .darkPool: return darkPoolStrength
        case .insider: return insiderStrength
        case .filing13F: return filingStrength
        case .earningsCalendar: return earningsEventRisk
        case .macroCalendar: return macroEventRisk
        }
    }

    func applying(_ value: Double, for kind: WealthExternalResearchKind) -> WealthNormalizedExternalSignal {
        switch kind {
        case .optionsFlow:
            return WealthNormalizedExternalSignal(
                optionsFlowStrength: value,
                darkPoolStrength: darkPoolStrength,
                insiderStrength: insiderStrength,
                filingStrength: filingStrength,
                earningsEventRisk: earningsEventRisk,
                macroEventRisk: macroEventRisk
            )
        case .darkPool:
            return WealthNormalizedExternalSignal(
                optionsFlowStrength: optionsFlowStrength,
                darkPoolStrength: value,
                insiderStrength: insiderStrength,
                filingStrength: filingStrength,
                earningsEventRisk: earningsEventRisk,
                macroEventRisk: macroEventRisk
            )
        case .insider:
            return WealthNormalizedExternalSignal(
                optionsFlowStrength: optionsFlowStrength,
                darkPoolStrength: darkPoolStrength,
                insiderStrength: value,
                filingStrength: filingStrength,
                earningsEventRisk: earningsEventRisk,
                macroEventRisk: macroEventRisk
            )
        case .filing13F:
            return WealthNormalizedExternalSignal(
                optionsFlowStrength: optionsFlowStrength,
                darkPoolStrength: darkPoolStrength,
                insiderStrength: insiderStrength,
                filingStrength: value,
                earningsEventRisk: earningsEventRisk,
                macroEventRisk: macroEventRisk
            )
        case .earningsCalendar:
            return WealthNormalizedExternalSignal(
                optionsFlowStrength: optionsFlowStrength,
                darkPoolStrength: darkPoolStrength,
                insiderStrength: insiderStrength,
                filingStrength: filingStrength,
                earningsEventRisk: value,
                macroEventRisk: macroEventRisk
            )
        case .macroCalendar:
            return WealthNormalizedExternalSignal(
                optionsFlowStrength: optionsFlowStrength,
                darkPoolStrength: darkPoolStrength,
                insiderStrength: insiderStrength,
                filingStrength: filingStrength,
                earningsEventRisk: earningsEventRisk,
                macroEventRisk: value
            )
        }
    }
}

protocol WealthExternalFeedClient {
    var kind: WealthExternalResearchKind { get }
    func signal(for blueprint: OpportunityBlueprint) -> WealthNormalizedExternalSignal
}

struct WealthOptionsFlowFeedClient: WealthExternalFeedClient {
    let kind: WealthExternalResearchKind = .optionsFlow

    func signal(for blueprint: OpportunityBlueprint) -> WealthNormalizedExternalSignal {
        WealthNormalizedExternalSignal(
            optionsFlowStrength: min(100, boostedScore(
                base: max(blueprint.optionsFlowStrength, blueprint.alternative * 0.42),
                text: [blueprint.sourceTrigger, blueprint.reviewSummary, blueprint.sourceSummary].joined(separator: " ").uppercased(),
                boosts: [("OPTIONS", 18), ("UNUSUAL", 10), ("CALL", 8), ("SWEEP", 8)]
            ))
        )
    }
}

struct WealthDarkPoolFeedClient: WealthExternalFeedClient {
    let kind: WealthExternalResearchKind = .darkPool

    func signal(for blueprint: OpportunityBlueprint) -> WealthNormalizedExternalSignal {
        WealthNormalizedExternalSignal(
            darkPoolStrength: min(100, boostedScore(
                base: max(blueprint.darkPoolStrength, blueprint.institutional * 0.46),
                text: (blueprint.intelligenceDrivers + blueprint.intelligenceChannels + [blueprint.sourceTrigger]).joined(separator: " ").uppercased(),
                boosts: [("DARK POOL", 20), ("ACCUMULATION", 10), ("PRINT", 7)]
            ))
        )
    }
}

struct WealthInsiderFeedClient: WealthExternalFeedClient {
    let kind: WealthExternalResearchKind = .insider

    func signal(for blueprint: OpportunityBlueprint) -> WealthNormalizedExternalSignal {
        WealthNormalizedExternalSignal(
            insiderStrength: min(100, boostedScore(
                base: max(blueprint.insiderStrength, blueprint.fundamental * 0.34),
                text: [blueprint.reviewSummary, blueprint.sourceSummary, blueprint.sourceTrigger].joined(separator: " ").uppercased(),
                boosts: [("INSIDER", 22), ("DIRECTOR", 8), ("CEO", 8), ("BUY", 6)]
            ))
        )
    }
}

struct WealthFiling13FFeedClient: WealthExternalFeedClient {
    let kind: WealthExternalResearchKind = .filing13F

    func signal(for blueprint: OpportunityBlueprint) -> WealthNormalizedExternalSignal {
        WealthNormalizedExternalSignal(
            filingStrength: min(100, boostedScore(
                base: max(blueprint.filingStrength, blueprint.institutional * 0.38),
                text: (blueprint.intelligenceDrivers + [blueprint.sourceTrigger, blueprint.reviewSummary]).joined(separator: " ").uppercased(),
                boosts: [("13F", 24), ("FILING", 8), ("FUND", 7), ("INSTITUTION", 7)]
            ))
        )
    }
}

struct WealthEarningsFeedClient: WealthExternalFeedClient {
    let kind: WealthExternalResearchKind = .earningsCalendar

    func signal(for blueprint: OpportunityBlueprint) -> WealthNormalizedExternalSignal {
        var risk = max(blueprint.earningsEventRisk, max(0, 55 - blueprint.catalyst * 0.25))
        let text = [blueprint.catalystBucket, blueprint.sourceSummary, blueprint.reviewSummary]
            .joined(separator: " ")
            .uppercased()

        if text.contains("EARNINGS") { risk += 22 }
        if text.contains("GUIDANCE") { risk += 10 }
        if blueprint.timeWindow == "HOURS" { risk += 8 }

        return WealthNormalizedExternalSignal(earningsEventRisk: min(100, risk))
    }
}

struct WealthMacroFeedClient: WealthExternalFeedClient {
    let kind: WealthExternalResearchKind = .macroCalendar

    func signal(for blueprint: OpportunityBlueprint) -> WealthNormalizedExternalSignal {
        var risk = max(blueprint.macroEventRisk, max(0, 48 - blueprint.sectorFlow * 0.20))
        let text = [blueprint.market, blueprint.sector, blueprint.reviewSummary, blueprint.sourceSummary]
            .joined(separator: " ")
            .uppercased()

        if text.contains("RATE") || text.contains("FED") { risk += 18 }
        if text.contains("CPI") || text.contains("INFLATION") { risk += 16 }
        if blueprint.market == "CRYPTO" { risk += 12 }
        if blueprint.market == "COMMODITY" { risk += 8 }

        return WealthNormalizedExternalSignal(macroEventRisk: min(100, risk))
    }
}

private func boostedScore(base: Double, text: String, boosts: [(String, Double)]) -> Double {
    boosts.reduce(base) { running, item in
        running + (text.contains(item.0) ? item.1 : 0)
    }
}
