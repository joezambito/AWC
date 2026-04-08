import SwiftUI
import Combine

struct PreparedMarketSignalSummarySeed {
    let region: String
    let market: String
    let rawCount: Int
    let greenCount: Int
    let blueCount: Int
    let purpleCount: Int
    let redCount: Int
    let greyCount: Int
    let accentTint: Color
}

enum PreparedMarketSignalRowSeed {
    case opportunity(Opportunity)
    case record(MarketUniverseRecord)

    var id: String {
        switch self {
        case .opportunity(let opportunity):
            return "\(opportunity.symbol)-\(opportunity.market)"
        case .record(let record):
            return record.id
        }
    }

    var symbol: String {
        switch self {
        case .opportunity(let opportunity):
            return opportunity.symbol
        case .record(let record):
            return record.symbol
        }
    }

    var market: String {
        switch self {
        case .opportunity(let opportunity):
            return opportunity.market
        case .record(let record):
            return record.market
        }
    }
}

struct PreparedMarketSignalInputSignature: Equatable {
    let engineLastRefresh: Date?
    let marketCardFingerprint: String
    let aiLiveResultFingerprint: String
    let activityOpportunityFingerprint: String
    let pendingHoldingFingerprint: String
    let universeRecordCount: Int
    let universeLastSuccessfulLoadAt: Date?
}

struct PreparedCoreInputSignature: Equatable {
    let engineLastRefresh: Date?
    let marketCardFingerprint: String
    let aiLiveResultFingerprint: String
    let activityOpportunityFingerprint: String
    let holdingFingerprint: String
    let completedActivityFingerprint: String
    let spendableCash: Double
    let dashboardFreezeActive: Bool
}

enum PreparedMarketSnapshotSupport {
    static let preferredRegionOrder = ["US", "CA", "EU", "APAC", "ME", "LATAM", "AFRICA", "AU", "FX", "CRYPTO", "GLOBAL", "UNKNOWN"]

    static func marketPriceText(price: Double, hasQuoteData: Bool) -> String {
        if hasQuoteData {
            return WealthFormat.money(price)
        }
        return marketQuotePendingDisplayText
    }
}

@MainActor
final class WealthPreparedSnapshotStore: ObservableObject {
    static let shared = WealthPreparedSnapshotStore()

    @Published private(set) var hasPreparedCore = false
    @Published private(set) var hasPreparedMarkets = false
    @Published private(set) var marketsBoardSummaries: [MarketRegionBoardSummary] = []
    @Published private(set) var marketsCompactRowsByRegion: [String: [MarketUniverseEntry]] = [:]
    @Published private(set) var aiLiveCards: [Opportunity] = []
    @Published private(set) var activityPendingCards: [Opportunity] = []
    @Published private(set) var activityPendingHoldings: [Holding] = []
    @Published private(set) var activityCompletedCards: [Opportunity] = []

    private(set) var marketsScopedWorldShareRecords: [MarketUniverseRecord] = []
    private(set) var marketsScopedWorldShareRecordsByRegion: [String: [MarketUniverseRecord]] = [:]
    private(set) var marketsEnabledRankedAssets: [Opportunity] = []
    private(set) var marketsOpportunityLookup: [String: Opportunity] = [:]
    private(set) var marketsOpportunitiesBySymbol: [String: [Opportunity]] = [:]
    private(set) var marketsRecordsBySymbol: [String: [MarketUniverseRecord]] = [:]
    private(set) var marketsLaneOpportunities: [Opportunity] = []
    private(set) var marketsLaneOpportunitiesByRegion: [String: [Opportunity]] = [:]
    private(set) var marketsImportedRecordsByRegion: [String: [MarketUniverseRecord]] = [:]
    private var marketSignalSummarySeeds: [PreparedMarketSignalSummarySeed] = []
    private var marketSignalRowsByRegion: [String: [PreparedMarketSignalRowSeed]] = [:]
    private var marketLiveRankByKey: [String: Int] = [:]
    private var lastCoreInputSignature: PreparedCoreInputSignature?
    private var lastMarketSignalInputSignature: PreparedMarketSignalInputSignature?
    private var visibleMarketRegions: Set<String> = []
    private var cancellables: Set<AnyCancellable> = []
    private var marketPriceRefreshTask: Task<Void, Never>?
    private var marketSequentialRegionRefreshTask: Task<Void, Never>?
    private var pendingCoreRefreshTask: Task<Void, Never>?
    private var marketsPresentationActive = false

    private init() {
        WealthBrokerQuoteStore.shared.$displayQuotes
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleMarketPriceRefresh()
            }
            .store(in: &cancellables)
    }
}
