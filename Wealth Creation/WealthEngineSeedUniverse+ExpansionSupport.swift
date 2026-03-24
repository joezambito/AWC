import Foundation

struct ExpandedSeedSpec {
    let symbol: String
    let market: String
    let sector: String
    let price: Double
    let tone: ExpandedTone
    let change: Double
}

enum ExpandedTone {
    case surge
    case active
    case watch
    case monitor
    case defensive
    case speculative
}

struct WealthExpandedSeedProfile {
    let technical: Double
    let fundamental: Double
    let alternative: Double
    let social: Double
    let institutional: Double
    let catalyst: Double
    let sectorFlow: Double
    let risk: Double
    let probability: Double
    let timeToTarget: String
    let prospect: String
    let timeWindow: String
    let catalystBucket: String
    let urgency: String
    let targetFitLabel: String
    let speedLabel: String
    let dataQualityLabel: String
    let optionsFlow: Double
    let darkPool: Double
    let insider: Double
    let filing: Double
    let spreadBps: Double
    let slippageRisk: Double
    let earningsRisk: Double
    let macroRisk: Double
    let newsScore: Int
    let analysisAge: TimeInterval
    let dataAge: TimeInterval
}

extension WealthEngineStore {
    static func makeExpandedBlueprint(from spec: ExpandedSeedSpec) -> OpportunityBlueprint {
        let region = WealthMarketLabels.display(for: spec.market)
        let shelfOnly = shouldStayCatalogFirst(spec)
        let profile = adjustedProfile(base: profile(for: spec.tone), shelfOnly: shelfOnly)
        let drivers = intelligenceDrivers(for: spec.tone, sector: spec.sector, shelfOnly: shelfOnly)
        let channels = intelligenceChannels(for: spec.market, shelfOnly: shelfOnly)
        let capitalFit = capitalFitLabel(for: spec.price)
        let trigger = shelfOnly ? "\(spec.sector) Shelf Candidate · \(region)" : "\(spec.sector) Flow · \(region)"
        let sourceSummary = shelfOnly
            ? "\(spec.symbol) is being kept in the wider market shelf, but AI still needs stronger company-specific evidence before it deserves the live stack."
            : "\(spec.symbol) keeps the \(region.lowercased()) shelf wide enough for the brain to surface fresh ideas each refresh."
        let reviewSummary = shelfOnly
            ? "AI is monitoring \(spec.symbol) as a catalog market candidate first, not as a conviction buy signal yet."
            : "AI is using \(spec.symbol) as part of the broader world market feed instead of recycling the same small set."

        return OpportunityBlueprint(
            symbol: spec.symbol,
            market: spec.market,
            sector: spec.sector,
            price: spec.price,
            technical: profile.technical,
            fundamental: profile.fundamental,
            alternative: profile.alternative,
            social: profile.social,
            institutional: profile.institutional,
            catalyst: profile.catalyst,
            sectorFlow: profile.sectorFlow,
            risk: profile.risk,
            probability: profile.probability,
            timeToTarget: profile.timeToTarget,
            prospect: profile.prospect,
            timeWindow: profile.timeWindow,
            catalystBucket: profile.catalystBucket,
            sourceTrigger: trigger,
            dataOrigin: dataOrigin(for: spec.market),
            sourceSummary: sourceSummary,
            reviewSummary: reviewSummary,
            intelligenceDrivers: drivers,
            intelligenceChannels: channels,
            urgency: profile.urgency,
            priceChangePercent: spec.change,
            targetFitLabel: profile.targetFitLabel,
            speedLabel: profile.speedLabel,
            capitalFitLabel: capitalFit,
            dataQualityLabel: profile.dataQualityLabel,
            optionsFlowStrength: profile.optionsFlow,
            darkPoolStrength: profile.darkPool,
            insiderStrength: profile.insider,
            filingStrength: profile.filing,
            averageDailyDollarVolume: liquidity(for: spec.price, tone: spec.tone, shelfOnly: shelfOnly),
            spreadBps: profile.spreadBps,
            slippageRisk: profile.slippageRisk,
            earningsEventRisk: profile.earningsRisk,
            macroEventRisk: profile.macroRisk,
            newsScore: profile.newsScore,
            analysisAge: profile.analysisAge,
            dataAge: profile.dataAge,
            orderState: .ready,
            submittedPriceOffset: 0
        )
    }
}
