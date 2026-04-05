import Foundation

// MARK: - OrderExecutionState

enum OrderExecutionState: String, Codable, Equatable {
    case pending
    case submitted
    case partiallyFilled
    case filled
    case cancelled
    case rejected
    case unknown
}

// MARK: - AdvancedSignal

struct AdvancedSignal: Codable, Equatable {
    var anomalyState: String = "STABLE"
    var executionState: String = "EXECUTION CLEAN"
}

// MARK: - ExecutionReadiness

struct ExecutionReadiness: Codable, Equatable {
    var reason: String?
}

// MARK: - Opportunity

final class Opportunity: Identifiable, Codable, Equatable, Hashable {

    let id: String
    var symbol: String
    var name: String
    var market: String
    var region: String
    var sector: String

    var rank: Int
    var aiScore: Int
    var confidence: Double
    var probability: Double
    var risk: Double

    var unrealizedPnL: Double
    var dataQualityLabel: String
    var aiRiskStance: String
    var hasFreshPromotionRefresh: Bool
    var isExecutionEligible: Bool
    var isMarketExecutableCandidate: Bool
    var marketQualityTier: String?

    var orderState: OrderExecutionState
    var advancedSignal: AdvancedSignal
    var executionReadiness: ExecutionReadiness

    var earningsEventRisk: Int
    var macroEventRisk: Int

    init(
        id: String = UUID().uuidString,
        symbol: String,
        name: String = "",
        market: String = "",
        region: String = "",
        sector: String = "",
        rank: Int = 0,
        aiScore: Int = 0,
        confidence: Double = 0,
        probability: Double = 0,
        risk: Double = 0,
        unrealizedPnL: Double = 0,
        dataQualityLabel: String = "",
        aiRiskStance: String = "STABLE",
        hasFreshPromotionRefresh: Bool = false,
        isExecutionEligible: Bool = false,
        isMarketExecutableCandidate: Bool = false,
        marketQualityTier: String? = nil,
        orderState: OrderExecutionState = .unknown,
        advancedSignal: AdvancedSignal = AdvancedSignal(),
        executionReadiness: ExecutionReadiness = ExecutionReadiness(),
        earningsEventRisk: Int = 0,
        macroEventRisk: Int = 0
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.market = market
        self.region = region
        self.sector = sector
        self.rank = rank
        self.aiScore = aiScore
        self.confidence = confidence
        self.probability = probability
        self.risk = risk
        self.unrealizedPnL = unrealizedPnL
        self.dataQualityLabel = dataQualityLabel
        self.aiRiskStance = aiRiskStance
        self.hasFreshPromotionRefresh = hasFreshPromotionRefresh
        self.isExecutionEligible = isExecutionEligible
        self.isMarketExecutableCandidate = isMarketExecutableCandidate
        self.marketQualityTier = marketQualityTier
        self.orderState = orderState
        self.advancedSignal = advancedSignal
        self.executionReadiness = executionReadiness
        self.earningsEventRisk = earningsEventRisk
        self.macroEventRisk = macroEventRisk
    }

    func withRank(_ rank: Int) -> Opportunity {
        let copy = Opportunity(
            id: id, symbol: symbol, name: name, market: market, region: region, sector: sector,
            rank: rank, aiScore: aiScore, confidence: confidence, probability: probability,
            risk: risk, unrealizedPnL: unrealizedPnL, dataQualityLabel: dataQualityLabel,
            aiRiskStance: aiRiskStance, hasFreshPromotionRefresh: hasFreshPromotionRefresh,
            isExecutionEligible: isExecutionEligible,
            isMarketExecutableCandidate: isMarketExecutableCandidate,
            marketQualityTier: marketQualityTier, orderState: orderState,
            advancedSignal: advancedSignal, executionReadiness: executionReadiness,
            earningsEventRisk: earningsEventRisk, macroEventRisk: macroEventRisk
        )
        return copy
    }

    var isCompleted: Bool { orderState == .filled }

    static func == (lhs: Opportunity, rhs: Opportunity) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Holding

struct Holding: Identifiable, Codable, Equatable {
    var id: String
    var symbol: String
    var market: String
    var orderState: OrderExecutionState
    var quantity: Double
    var averageCost: Double

    init(
        id: String = UUID().uuidString,
        symbol: String,
        market: String = "",
        orderState: OrderExecutionState = .unknown,
        quantity: Double = 0,
        averageCost: Double = 0
    ) {
        self.id = id
        self.symbol = symbol
        self.market = market
        self.orderState = orderState
        self.quantity = quantity
        self.averageCost = averageCost
    }
}

// MARK: - MarketSignal

struct MarketSignal: Identifiable, Codable, Equatable {
    var id: String
    var symbol: String
    var signalType: String
    var value: Double
    var generatedAt: Date

    init(
        id: String = UUID().uuidString,
        symbol: String,
        signalType: String = "",
        value: Double = 0,
        generatedAt: Date = .now
    ) {
        self.id = id
        self.symbol = symbol
        self.signalType = signalType
        self.value = value
        self.generatedAt = generatedAt
    }
}
