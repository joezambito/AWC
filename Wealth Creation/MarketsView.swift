import SwiftUI
import Combine

@MainActor
struct MarketsView: View {
    private enum StorageKey {
        static let scanUS = "awc_scan_market_nasdaq"
        static let scanASX = "awc_scan_market_asx"
        static let scanCanada = "awc_scan_market_canada"
        static let scanEurope = "awc_scan_market_europe"
        static let scanAsia = "awc_scan_market_asia"
        static let scanMiddleEast = "awc_scan_market_middleeast"
        static let scanRussia = "awc_scan_market_russia"
        static let scanLatam = "awc_scan_market_latam"
        static let scanAfrica = "awc_scan_market_africa"
        static let scanFX = "awc_scan_market_forex"
        static let scanCrypto = "awc_scan_market_crypto"
        static let scanCommodities = "awc_scan_market_commodities"
        static let themeDefense = "awc_scan_theme_defense"
        static let themeMiners = "awc_scan_theme_miners"
        static let themeCatalysts = "awc_scan_theme_catalysts"
        static let themeEarnings = "awc_scan_theme_earnings"
        static let themeSmartMoney = "awc_scan_theme_smartmoney"
        static let themeMomentum = "awc_scan_theme_momentum"
        static let persistedExpandedMarketRegion = "awc_markets_expanded_region"
        static let persistedExpandedMarketBucket = "awc_markets_expanded_bucket"
        static let persistedVisibleMarketBucketCount = "awc_markets_visible_bucket_count"
    }

    @ObservedObject var engine = WealthEngineStore.shared
    @ObservedObject var allCardsStore = WealthAllCardsStore.shared
    @ObservedObject var greenCardsStore = WealthGreenCardsStore.shared
    @ObservedObject var blueCardsStore = WealthBlueCardsStore.shared
    @ObservedObject var purpleCardsStore = WealthPurpleCardsStore.shared
    @ObservedObject var redCardsStore = WealthRedCardsStore.shared
    @ObservedObject var quoteStore = WealthBrokerQuoteStore.shared
    @ObservedObject var syncStore = WealthSyncStore.shared
    @ObservedObject var protectionStore = WealthProtectionSettingsStore.shared
    @ObservedObject var universeStore = WealthMarketUniverseStore.shared
    let preparedSnapshot = WealthPreparedSnapshotStore.shared
    let marketViewCycleStore = WealthMarketViewCycleStore.shared

    @State var expandedRegions: Set<String> = []
    @State var expandedSymbols: Set<String> = []
    @State var expandedMarketRegion: String?
    @State var expandedMarketBucket: String?
    @State var expandedTop100GroupIndex: Int? = 0
    @State var visibleMarketBucketCount = 50
    @State var phoneMarketCycleStage = 0
    @State var phoneMarketCycleTask: Task<Void, Never>?
    @State var deferredMarketsStartupTask: Task<Void, Never>?
    @State var marketFeedScanBatchIndex = 0
    @State var selectedPhoneMarketCode = "USA"
    @State var selectedPhoneMarketLetterBucket = "A"
    @State var phoneMarketBucketPages: [String: Int] = [:]
    @State var phoneMarketBucketIDCache: [String: [String: [String]]] = [:]
    @State var lastPreparedImportedUniverseIDs: [String] = []
    @State var lastPreparedImportedUniverseBrokerConnected = false
    @State var lastPreparedImportedUniverseDelayedQuotes = true
    @StateObject var browserStore = WealthMarketBrowserStore()

    @AppStorage(StorageKey.persistedExpandedMarketRegion) var persistedExpandedMarketRegion = ""
    @AppStorage(StorageKey.persistedExpandedMarketBucket) var persistedExpandedMarketBucket = ""
    @AppStorage(StorageKey.persistedVisibleMarketBucketCount) var persistedVisibleMarketBucketCount = 50

    @AppStorage(StorageKey.scanUS) var scanUS = true
    @AppStorage(StorageKey.scanASX) var scanASX = true
    @AppStorage(StorageKey.scanCanada) var scanCanada = true
    @AppStorage(StorageKey.scanEurope) var scanEurope = true
    @AppStorage(StorageKey.scanAsia) var scanAsia = true
    @AppStorage(StorageKey.scanMiddleEast) var scanMiddleEast = true
    @AppStorage(StorageKey.scanRussia) var scanRussia = true
    @AppStorage(StorageKey.scanLatam) var scanLatam = true
    @AppStorage(StorageKey.scanAfrica) var scanAfrica = true
    @AppStorage(StorageKey.scanFX) var scanFX = true
    @AppStorage(StorageKey.scanCrypto) var scanCrypto = true
    @AppStorage(StorageKey.scanCommodities) var scanCommodities = true

    @AppStorage(StorageKey.themeDefense) var themeDefense = true
    @AppStorage(StorageKey.themeMiners) var themeMiners = true
    @AppStorage(StorageKey.themeCatalysts) var themeCatalysts = true
    @AppStorage(StorageKey.themeEarnings) var themeEarnings = true
    @AppStorage(StorageKey.themeSmartMoney) var themeSmartMoney = true
    @AppStorage(StorageKey.themeMomentum) var themeMomentum = true

    private var marketsContent: some View {
        VStack(spacing: hasDesktopLayout ? 10 : 8) {
            if hasDesktopLayout {
                GeometryReader { proxy in
                    desktopBody(isWide: proxy.size.width >= 920)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            } else {
                phoneBody
            }
        }
    }

    private var browserAwareContent: some View {
        marketsContent
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .onAppear(perform: handleAppear)
            .onChange(of: browserStore.searchText) { _, _ in browserStore.resetPagination() }
            .onChange(of: browserStore.selectedAssetType) { _, _ in browserStore.resetPagination() }
            .onChange(of: browserStore.selectedRegion) { _, _ in browserStore.resetPagination() }
            .onChange(of: browserStore.selectedCountry) { _, _ in browserStore.resetPagination() }
            .onChange(of: browserStore.selectedExchange) { _, _ in browserStore.resetPagination() }
            .onChange(of: browserStore.selectedCurrency) { _, _ in browserStore.resetPagination() }
    }

    var body: some View {
        browserAwareContent
            .onChange(of: universeStore.records) { _, _ in
                browserStore.resetPagination()
                subscribeImportedUniverseIfNeeded()
            }
            .onChange(of: engine.lastRefresh) { _, _ in
                if hasDesktopLayout {
                    guard engine.startupPostSequenceReady else { return }
                    prepareSharedMarketFeedInputs()
                    prepareMarketBoardContent()
                    syncMarketViewCycleSelection()
                    syncVisibleMarketQuoteScope()
                } else {
                    guard engine.startupPostSequenceReady else { return }
                    deferredMarketsStartupTask?.cancel()
                    deferredMarketsStartupTask = Task { @MainActor in
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        syncMarketViewCycleSelection()
                        syncVisibleMarketQuoteScope()
                        marketFeedScanBatchIndex += 1
                    }
                }
            }
            .onChange(of: phoneMarketCycleStage) { _, _ in
                guard engine.startupPostSequenceReady else { return }
                syncVisibleMarketQuoteScope()
                subscribeImportedUniverseIfNeeded()
            }
            .onChange(of: syncStore.syncStatus) { _, _ in
                guard hasDesktopLayout || engine.startupPostSequenceReady else { return }
                syncVisibleMarketQuoteScope()
                subscribeImportedUniverseIfNeeded()
            }
            .onChange(of: selectedPhoneMarketCode) { _, _ in
                subscribeImportedUniverseIfNeeded()
            }
            .onChange(of: selectedPhoneMarketLetterBucket) { _, _ in
                subscribeImportedUniverseIfNeeded()
            }
            .onChange(of: phoneMarketBucketPages) { _, _ in
                guard hasDesktopLayout || engine.startupPostSequenceReady else { return }
                syncVisibleMarketQuoteScope()
                subscribeImportedUniverseIfNeeded()
            }
            .onChange(of: expandedMarketRegion) { _, _ in
                syncVisibleMarketQuoteScope()
            }
            .onChange(of: engine.activationCycleComplete) { _, isComplete in
                guard isComplete, engine.startupPostSequenceReady else { return }
                completeStartupMarketActivation()
            }
            .onChange(of: engine.startupPostSequenceReady) { _, isReady in
                guard isReady else { return }
                completeStartupMarketActivation()
            }
            .onDisappear {
                phoneMarketCycleTask?.cancel()
                deferredMarketsStartupTask?.cancel()
                preparedSnapshot.setMarketsPresentationActive(false)
                preparedSnapshot.setVisibleMarketRegions([])
                quoteStore.setVisibleQuoteKeys([])
            }
    }

    private func completeStartupMarketActivation() {
        if hasDesktopLayout {
            universeStore.loadIfNeeded()
            prepareSharedMarketFeedInputs()
            prepareMarketBoardContent()
            syncMarketViewCycleSelection()
            syncVisibleMarketQuoteScope()
            subscribeImportedUniverseIfNeeded()
            return
        }

        syncMarketViewCycleSelection()
        syncVisibleMarketQuoteScope()
    }

    func prepareMarketBoardContent() {
        guard !hasDesktopLayout else { return }
        refreshPhoneAlphabetBlockCache()
    }

    func prepareSharedMarketFeedInputs() {
        guard hasDesktopLayout else { return }
        preparedSnapshot.refreshMarkets(
            engine: engine,
            portfolio: lanePortfolio,
            universeStore: universeStore,
            quoteStore: quoteStore
        )
    }

    func syncMarketViewCycleSelection() {
        let marketCandidates = WealthAllCardsStore.shared.currentMarketCards(preferredRefreshTime: engine.lastRefresh)
        marketViewCycleStore.syncCycle(
            candidates: marketCandidates,
            cycleMarker: engine.lastRefresh
        )
    }

    func syncVisibleMarketQuoteScope() {
        if hasDesktopLayout {
            let visibleRegions = expandedMarketRegion.map { Set([$0]) } ?? []
            preparedSnapshot.setVisibleMarketRegions(visibleRegions, quoteStore: quoteStore)
            return
        }

        preparedSnapshot.setVisibleMarketRegions([], quoteStore: quoteStore)
        let activeCandidates = marketViewCycleStore.activeCandidates
        let visibleQuoteKeys = Set(
            activeCandidates.map { WealthBrokerQuoteKey(symbol: $0.symbol, market: $0.market) }
        )
        quoteStore.setVisibleQuoteKeys(visibleQuoteKeys)

        if !activeCandidates.isEmpty {
            quoteStore.prepareSubscriptions(for: activeCandidates)
        }
    }
}
