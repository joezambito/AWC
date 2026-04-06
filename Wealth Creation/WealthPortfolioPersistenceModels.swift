import Foundation

extension WealthPortfolioStore {
    struct PersistedOpportunity: Codable {
        let rank: Int
        let symbol: String
        let market: String
        let sector: String
        let aiScore: Int
        let confidence: Int
        let safety: Int
        let probabilityOfSuccess: Int
        let newsScore: Int
        let recommendedShares: Int
        let price: Double
        let brokerFee: Double
        let expectedProfit: Double
        let prospect: String
        let timeToTarget: String
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
        let analysisTimestamp: Date
        let dataTimestamp: Date
        let lastRefreshTimestamp: Date?
        let brokerName: String
        let orderStateRaw: String
        let submittedPrice: Double
        let submittedShares: Int
        let actualExitPrice: Double?
        let actualRealizedProfit: Double?
        let actualRealizedNetProfit: Double?
        let completedAt: Date?
        let decisionBiasRaw: String
        let aggressionModeRaw: String
        let marketRegimeRaw: String
        let targetPressureLabel: String
        let capitalDisciplineLabel: String
        let allocationPercent: Int
        let positionSizePercent: Int
        let convictionRaw: String
        let permissionRaw: String
        let rotationBiasRaw: String
        let hungerModeRaw: String
        let executionStyleRaw: String
        let commandText: String
        let priorityScore: Int
        let targetDirective: String
        let targetCoveragePercent: Int
        let sourceReliabilityScore: Int
        let shareReliabilityScore: Int
        let optionsFlowStrength: Double
        let darkPoolStrength: Double
        let insiderStrength: Double
        let filingStrength: Double
        let earningsEventRisk: Double
        let macroEventRisk: Double
        let trustStateRaw: String
        let trustReason: String
        let buyReason: String
        let rotationReason: String
        let warningReason: String
    }

    struct PersistedHolding: Codable {
        let symbol: String
        let market: String
        let sector: String
        let shares: Int
        let averagePrice: Double
        let currentPrice: Double
        let aiScore: Int
        let aiBand: Int
        let confidence: Int
        let safety: Int
        let prospect: String
        let timeWindow: String
        let riskLabel: String
        let holdLabel: String
        let safeKeepLabel: String
        let lockLabel: String
        let sourceTrigger: String
        let dataOrigin: String
        let reviewSummary: String
        let researchSummary: String
        let analysisTimestamp: Date
        let dataTimestamp: Date
        let lastRefreshTimestamp: Date?
        let filledAt: Date?
        let orderIntentRaw: String
        let orderStateRaw: String
        let pendingShares: Int
        let submittedExitPrice: Double?
        let orderSubmittedAt: Date?
    }

    struct PersistedSaleGate: Codable {
        let symbol: String
        let market: String
        let lastSoldPrice: Double
        let soldAt: Date
        let cooldownUntil: Date?
        let cooldownReason: String?

        var key: String {
            guard !market.isEmpty else { return symbol.uppercased() }
            return "\(symbol.uppercased())-\(market.uppercased())"
        }

        init(
            symbol: String,
            market: String,
            lastSoldPrice: Double,
            soldAt: Date,
            cooldownUntil: Date?,
            cooldownReason: String?
        ) {
            self.symbol = symbol
            self.market = market
            self.lastSoldPrice = lastSoldPrice
            self.soldAt = soldAt
            self.cooldownUntil = cooldownUntil
            self.cooldownReason = cooldownReason
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            symbol = try container.decode(String.self, forKey: .symbol)
            market = try container.decodeIfPresent(String.self, forKey: .market) ?? ""
            lastSoldPrice = try container.decode(Double.self, forKey: .lastSoldPrice)
            soldAt = try container.decode(Date.self, forKey: .soldAt)
            cooldownUntil = try container.decodeIfPresent(Date.self, forKey: .cooldownUntil)
            cooldownReason = try container.decodeIfPresent(String.self, forKey: .cooldownReason)
        }
    }
}
