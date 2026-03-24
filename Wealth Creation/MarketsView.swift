import SwiftUI

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
    }

    @ObservedObject var engine = WealthEngineStore.shared
    @ObservedObject var quoteStore = WealthBrokerQuoteStore.shared
    @ObservedObject var syncStore = WealthSyncStore.shared
    @ObservedObject var protectionStore = WealthProtectionSettingsStore.shared

    @State var expandedRegions: Set<String> = []
    @State var expandedSymbols: Set<String> = []
    @State var phoneMarketCycleStage = 0
    @State var phoneMarketCycleTask: Task<Void, Never>?
    @State var marketFeedScanBatchIndex = 0
    @StateObject var universeStore = WealthMarketUniverseStore()
    @StateObject var browserStore = WealthMarketBrowserStore()

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

    var body: some View {
        VStack(spacing: hasDesktopLayout ? 10 : 8) {
            if hasDesktopLayout {
                GeometryReader { proxy in
                    desktopBody(isWide: proxy.size.width >= 920)
                }
                .frame(maxWidth: .infinity, minHeight: 1280, alignment: .top)
            } else {
                phoneBody
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear(perform: handleAppear)
        .onChange(of: browserStore.searchText) { _, _ in browserStore.resetPagination() }
        .onChange(of: browserStore.selectedAssetType) { _, _ in browserStore.resetPagination() }
        .onChange(of: browserStore.selectedRegion) { _, _ in browserStore.resetPagination() }
        .onChange(of: browserStore.selectedCountry) { _, _ in browserStore.resetPagination() }
        .onChange(of: browserStore.selectedExchange) { _, _ in browserStore.resetPagination() }
        .onChange(of: browserStore.selectedCurrency) { _, _ in browserStore.resetPagination() }
        .onChange(of: universeStore.records) { _, _ in
            browserStore.resetPagination()
            subscribeImportedUniverseIfNeeded()
        }
        .onChange(of: engine.lastRefresh) { _, _ in
            guard !hasDesktopLayout else { return }
            marketFeedScanBatchIndex += 1
        }
        .onChange(of: phoneMarketCycleStage) { _, _ in
            subscribeImportedUniverseIfNeeded()
        }
        .onChange(of: syncStore.syncStatus) { _, _ in
            subscribeImportedUniverseIfNeeded()
        }
    }
}
