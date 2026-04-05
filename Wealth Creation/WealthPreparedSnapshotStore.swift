import Foundation
import Combine

// MARK: - Supporting types for WealthPreparedSnapshotStore

struct MarketRegionBoardSummary {
    let region: String
    let recordCount: Int
}

struct MarketUniverseEntry {
    let record: MarketUniverseRecord
    let opportunity: Opportunity?
}

struct PreparedMarketSignalSummarySeed {
    let symbol: String
}

struct PreparedMarketSignalRowSeed {
    let symbol: String
}

struct PreparedCoreInputSignature: Equatable {
    let rankedAssetCount: Int
    let activityCount: Int
    let holdingCount: Int
}

struct PreparedMarketSignalInputSignature: Equatable {
    let recordCount: Int
    let cycleMarker: Date?
}

// MARK: - WealthPreparedSnapshotStore

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

    // MARK: - Public API

    func refreshCore() {
        refreshCore(engine: .shared, portfolio: .shared)
    }

    func requestCoreRefresh() {
        pendingCoreRefreshTask?.cancel()
        pendingCoreRefreshTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.pendingCoreRefreshTask = nil
            self.refreshCore(engine: .shared, portfolio: .shared)
        }
    }

    func invalidatePreparedMarkets() {
        hasPreparedMarkets = false
    }

    func refreshCore(engine: WealthEngineStore, portfolio: WealthPortfolioStore) {
        let ranked = engine.rankedAssets
        let liveKeys = Set(WealthAllCardsStore.shared.livePickKeys)
        aiLiveCards = ranked.filter { liveKeys.contains($0.symbol) }
        hasPreparedCore = true
    }

    func refreshMarkets(
        engine: WealthEngineStore,
        portfolio: WealthPortfolioStore,
        universeStore: WealthMarketUniverseStore,
        quoteStore: WealthBrokerQuoteStore
    ) {
        let ranked = engine.rankedAssets.filter { $0.rank > 0 }
        marketsEnabledRankedAssets = ranked
        marketsOpportunityLookup = Dictionary(uniqueKeysWithValues: ranked.map { ($0.symbol, $0) })
        marketsOpportunitiesBySymbol = Dictionary(grouping: ranked, by: \.symbol)
        marketsScopedWorldShareRecords = universeStore.worldShareRecords
        marketsScopedWorldShareRecordsByRegion = universeStore.worldShareRecordsByRegion
        marketsRecordsBySymbol = Dictionary(grouping: universeStore.records, by: \.symbol)

        let boardSummaries = universeStore.worldShareRecordsByRegion.map { region, records in
            MarketRegionBoardSummary(region: region, recordCount: records.count)
        }.sorted { $0.region < $1.region }
        marketsBoardSummaries = boardSummaries

        hasPreparedMarkets = true
    }

    // MARK: - Private

    private func scheduleMarketPriceRefresh() {
        marketPriceRefreshTask?.cancel()
        marketPriceRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard let self, !Task.isCancelled else { return }
            self.marketPriceRefreshTask = nil
            if self.hasPreparedMarkets {
                self.refreshCore(engine: .shared, portfolio: .shared)
            }
        }
    }
}
