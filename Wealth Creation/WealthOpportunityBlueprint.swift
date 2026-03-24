import Foundation

struct OpportunityBlueprint: Identifiable, Hashable {
    let id: UUID
    let symbol: String
    let market: String
    let sector: String
    let price: Double
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
    let sourceTrigger: String
    let dataOrigin: String
    let sourceSummary: String
    let reviewSummary: String
    let intelligenceDrivers: [String]
    let intelligenceChannels: [String]
    let urgency: String
    let priceChangePercent: Double
    let targetFitLabel: String
    let speedLabel: String
    let capitalFitLabel: String
    let dataQualityLabel: String
    let optionsFlowStrength: Double
    let darkPoolStrength: Double
    let insiderStrength: Double
    let filingStrength: Double
    let averageDailyDollarVolume: Double
    let spreadBps: Double
    let slippageRisk: Double
    let earningsEventRisk: Double
    let macroEventRisk: Double
    let newsScore: Int
    let analysisAge: TimeInterval
    let dataAge: TimeInterval
    let orderState: OrderExecutionState
    let submittedPriceOffset: Double

    init(
        symbol: String,
        market: String,
        sector: String,
        price: Double,
        technical: Double,
        fundamental: Double,
        alternative: Double,
        social: Double,
        institutional: Double,
        catalyst: Double,
        sectorFlow: Double,
        risk: Double,
        probability: Double,
        timeToTarget: String,
        prospect: String,
        timeWindow: String,
        catalystBucket: String,
        sourceTrigger: String,
        dataOrigin: String,
        sourceSummary: String,
        reviewSummary: String,
        intelligenceDrivers: [String] = [],
        intelligenceChannels: [String] = [],
        urgency: String,
        priceChangePercent: Double,
        targetFitLabel: String,
        speedLabel: String,
        capitalFitLabel: String,
        dataQualityLabel: String,
        optionsFlowStrength: Double = 0,
        darkPoolStrength: Double = 0,
        insiderStrength: Double = 0,
        filingStrength: Double = 0,
        averageDailyDollarVolume: Double = 0,
        spreadBps: Double = 0,
        slippageRisk: Double = 0,
        earningsEventRisk: Double = 0,
        macroEventRisk: Double = 0,
        newsScore: Int,
        analysisAge: TimeInterval,
        dataAge: TimeInterval,
        orderState: OrderExecutionState,
        submittedPriceOffset: Double,
        id: UUID = UUID()
    ) {
        self.id = id
        self.symbol = symbol
        self.market = market
        self.sector = sector
        self.price = price
        self.technical = technical
        self.fundamental = fundamental
        self.alternative = alternative
        self.social = social
        self.institutional = institutional
        self.catalyst = catalyst
        self.sectorFlow = sectorFlow
        self.risk = risk
        self.probability = probability
        self.timeToTarget = timeToTarget
        self.prospect = prospect
        self.timeWindow = timeWindow
        self.catalystBucket = catalystBucket
        self.sourceTrigger = sourceTrigger
        self.dataOrigin = dataOrigin
        self.sourceSummary = sourceSummary
        self.reviewSummary = reviewSummary
        self.intelligenceDrivers = intelligenceDrivers
        self.intelligenceChannels = intelligenceChannels
        self.urgency = urgency
        self.priceChangePercent = priceChangePercent
        self.targetFitLabel = targetFitLabel
        self.speedLabel = speedLabel
        self.capitalFitLabel = capitalFitLabel
        self.dataQualityLabel = dataQualityLabel
        self.optionsFlowStrength = optionsFlowStrength
        self.darkPoolStrength = darkPoolStrength
        self.insiderStrength = insiderStrength
        self.filingStrength = filingStrength
        self.averageDailyDollarVolume = averageDailyDollarVolume
        self.spreadBps = spreadBps
        self.slippageRisk = slippageRisk
        self.earningsEventRisk = earningsEventRisk
        self.macroEventRisk = macroEventRisk
        self.newsScore = newsScore
        self.analysisAge = analysisAge
        self.dataAge = dataAge
        self.orderState = orderState
        self.submittedPriceOffset = submittedPriceOffset
    }
}
