import Foundation
import Combine
import OSLog

@MainActor
final class WealthBrokerQuoteStore: ObservableObject {
    static let shared = WealthBrokerQuoteStore()

    private enum MarketQuotePolicy {
        static let freshReuseWindow: TimeInterval = 20
        static let uiPublishThrottleNanoseconds: UInt64 = 750_000_000
    }

    @Published private(set) var displayQuotes: [WealthBrokerQuoteKey: WealthBrokerQuote] = [:]
    private let logger = Logger(subsystem: "com.zulugames.awc", category: "BrokerQuoteStore")
    private var rawQuotes: [WealthBrokerQuoteKey: WealthBrokerQuote] = [:]
    private var visibleQuoteKeys: Set<WealthBrokerQuoteKey> = []
    private var pendingDisplayRefreshTask: Task<Void, Never>?

    private init() {}

    var rawQuoteSymbolCount: Int {
        rawQuotes.count
    }

    private var canRequestBrokerQuotes: Bool {
        WealthIBKRBridge.shared.hasOpenConnection
            || WealthSyncStore.shared.isTWSConnectedForQuotes
    }

    private var isDebugLoggingEnabled: Bool {
        WealthBrokerStore.shared.brokerDisplayMode == .debug && WealthPipelineTraceLogger.isEnabledForDebugOutput
    }

    func prepareSubscriptions(for blueprints: [OpportunityBlueprint]) {
        guard canRequestBrokerQuotes else { return }

        let marketContracts = blueprints.compactMap(WealthIBKRContractMapper.contract(for:))
        let fxContracts = Set(
            marketContracts.compactMap { WealthFXConversionStore.fxContract(for: $0.currency) }
        )
        let useDelayed = WealthProtectionSettingsStore.shared.demoMode || !WealthSyncStore.shared.liveMode
        WealthIBKRBridge.shared.subscribe(to: Array(Set(marketContracts).union(fxContracts)), delayedQuotes: useDelayed)
    }

    func prepareSubscriptions(for opportunities: [Opportunity]) {
        guard canRequestBrokerQuotes else { return }

        let marketContracts = opportunities.compactMap(WealthIBKRContractMapper.contract(for:))
        let fxContracts = Set(
            marketContracts.compactMap { WealthFXConversionStore.fxContract(for: $0.currency) }
        )
        let useDelayed = WealthProtectionSettingsStore.shared.demoMode || !WealthSyncStore.shared.liveMode
        WealthIBKRBridge.shared.subscribe(to: Array(Set(marketContracts).union(fxContracts)), delayedQuotes: useDelayed)
    }

    func prepareSubscriptions(for records: [MarketUniverseRecord]) {
        let useDelayed = WealthProtectionSettingsStore.shared.demoMode || !WealthSyncStore.shared.liveMode
        let uniqueRecords = deduplicatedRecords(records)
        let resolutionsByRecordID = Dictionary(
            uniqueKeysWithValues: uniqueRecords.map { record in
                (record.id, WealthIBKRInstrumentResolver.resolution(for: record))
            }
        )
        let invalidContracts = uniqueRecords.compactMap { record -> WealthBrokerQuoteKey? in
            guard let resolution = resolutionsByRecordID[record.id], !resolution.isSupportedEquity else { return nil }
            return WealthBrokerQuoteKey(symbol: record.symbol, market: record.market)
        }
        WealthLiveMarketDataStore.shared.setInvalidContracts(invalidContracts)

        let quoteableRecords = uniqueRecords.filter { record in
            resolutionsByRecordID[record.id]?.isSupportedEquity == true
        }
        let reusableFreshRecords = quoteableRecords.filter { hasFreshMarketQuote(for: $0) }
        let requestedRecords = quoteableRecords.filter { !hasFreshMarketQuote(for: $0) }
        let missingRecords = requestedRecords.filter { !hasAnyMarketQuote(for: $0) }
        let staleRecords = requestedRecords.filter { hasAnyMarketQuote(for: $0) }

        #if DEBUG
        if isDebugLoggingEnabled {
            print(
                "MARKET QUOTE REQUEST:",
                "total=\(uniqueRecords.count)",
                "quoteable=\(quoteableRecords.count)",
                "freshReused=\(reusableFreshRecords.count)",
                "requested=\(requestedRecords.count)",
                "missing=\(missingRecords.count)",
                "stale=\(staleRecords.count)",
                "invalid=\(invalidContracts.count)",
                "source=\(WealthSyncStore.shared.isTWSConnectedForQuotes ? "TWS" : "OFFLINE")",
                "delayed=\(useDelayed)"
            )
            let supportedByRegion = Dictionary(
                grouping: quoteableRecords,
                by: { regionBucket(for: $0.market) }
            ).mapValues(\.count)
            let invalidByRegion = Dictionary(
                grouping: uniqueRecords.filter { resolutionsByRecordID[$0.id]?.isSupportedEquity != true },
                by: { regionBucket(for: $0.market) }
            ).mapValues(\.count)
            print(
                "[IBKRTrace] stage=record_support total=\(uniqueRecords.count) " +
                "quoteable=\(quoteableRecords.count) invalid=\(invalidContracts.count) " +
                "supportedRegions={AU:\(supportedByRegion["AU", default: 0]),US:\(supportedByRegion["US", default: 0]),EU:\(supportedByRegion["EU", default: 0]),Other:\(supportedByRegion["Other", default: 0])} " +
                "invalidRegions={AU:\(invalidByRegion["AU", default: 0]),US:\(invalidByRegion["US", default: 0]),EU:\(invalidByRegion["EU", default: 0]),Other:\(invalidByRegion["Other", default: 0])}"
            )
        }
        #endif

        guard !requestedRecords.isEmpty else { return }

        if WealthSyncStore.shared.isTWSConnectedForQuotes {
            WealthWorldMarketOfflineQuotePass.shared.stop()
            WealthWorldMarketBulkQuotePass.shared.start(
                records: requestedRecords,
                quotes: rawQuotes,
                delayedQuotes: useDelayed
            )
        } else {
            WealthWorldMarketBulkQuotePass.shared.stop()
            WealthWorldMarketOfflineQuotePass.shared.start(records: requestedRecords)
        }
    }

    func ingest(_ quote: WealthBrokerQuote) {
        rawQuotes[quote.key] = quote
        if isDebugLoggingEnabled {
            logger.log(
                "QUOTE STORE WRITE symbol=\(quote.key.symbol, privacy: .public) market=\(quote.key.market, privacy: .public) price=\(quote.price, privacy: .public) delayed=\(quote.isDelayed, privacy: .public)"
            )
        }
        WealthLiveMarketDataStore.shared.noteQuote(quote)
        guard visibleQuoteKeys.contains(quote.key) else { return }
        scheduleDisplayRefresh()
    }

    func clear() {
        rawQuotes.removeAll()
        displayQuotes.removeAll()
        visibleQuoteKeys.removeAll()
        pendingDisplayRefreshTask?.cancel()
        pendingDisplayRefreshTask = nil
        WealthLiveMarketDataStore.shared.clearQuotes()
        WealthWorldMarketBulkQuotePass.shared.stop()
        WealthWorldMarketOfflineQuotePass.shared.stop()
    }

    func setVisibleQuoteKeys(_ keys: Set<WealthBrokerQuoteKey>) {
        guard keys != visibleQuoteKeys else { return }
        visibleQuoteKeys = keys
        scheduleDisplayRefresh()
    }

    func marketDisplayQuote(symbol: String, market: String) -> WealthBrokerQuote? {
        let exactKey = WealthBrokerQuoteKey(symbol: symbol, market: market)
        if let exact = rawQuotes[exactKey] {
            return exact
        }

        let symbolMatches = rawQuotes.values.filter {
            $0.key.symbol.caseInsensitiveCompare(symbol) == .orderedSame
        }

        if symbolMatches.count == 1 {
            return symbolMatches.first
        }

        return symbolMatches.first {
            $0.key.market.caseInsensitiveCompare(market) == .orderedSame
        }
    }

    private func deduplicatedRecords(_ records: [MarketUniverseRecord]) -> [MarketUniverseRecord] {
        var seen: Set<String> = []
        return records.filter { seen.insert($0.id).inserted }
    }

    private func hasFreshMarketQuote(for record: MarketUniverseRecord, now: Date = .now) -> Bool {
        guard let quote = marketDisplayQuote(symbol: record.symbol, market: record.market) else { return false }
        guard now.timeIntervalSince(quote.timestamp) <= MarketQuotePolicy.freshReuseWindow else { return false }
        return quote.price > 0
    }

    private func hasAnyMarketQuote(for record: MarketUniverseRecord) -> Bool {
        marketDisplayQuote(symbol: record.symbol, market: record.market) != nil
    }

    func liveQuote(
        for blueprint: OpportunityBlueprint,
        previous: Opportunity?,
        refreshTime: Date,
        sessionOpen: Bool
    ) -> WealthLiveQuote {
        let key = WealthBrokerQuoteKey(symbol: blueprint.symbol, market: blueprint.market)

        if let brokerQuote = rawQuotes[key] {
            let conversionRate = WealthFXConversionStore.rateToAUD(for: brokerQuote.currency, quotes: rawQuotes)
            let convertedPrice = brokerQuote.price * conversionRate
            let convertedClose = (brokerQuote.close ?? brokerQuote.price) * conversionRate
            return WealthLiveQuote(
                price: convertedPrice,
                changePercent: convertedClose > 0 ? ((convertedPrice / convertedClose) - 1) * 100 : brokerQuote.changePercent,
                dataAge: max(0, refreshTime.timeIntervalSince(brokerQuote.timestamp))
            )
        }

        let fallback = WealthLivePricingEngine.quote(
            for: blueprint,
            previous: previous,
            refreshTime: refreshTime,
            sessionOpen: sessionOpen
        )
        let currency = WealthIBKRContractMapper.contract(for: blueprint)?.currency ?? "AUD"
        let conversionRate = WealthFXConversionStore.rateToAUD(for: currency, quotes: rawQuotes)

        return WealthLiveQuote(
            price: fallback.price * conversionRate,
            changePercent: fallback.changePercent,
            dataAge: fallback.dataAge
        )
    }

    private func scheduleDisplayRefresh() {
        guard pendingDisplayRefreshTask == nil else { return }
        pendingDisplayRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: MarketQuotePolicy.uiPublishThrottleNanoseconds)
            guard let self, !Task.isCancelled else { return }
            self.flushDisplayRefresh()
        }
    }

    private func flushDisplayRefresh() {
        pendingDisplayRefreshTask?.cancel()
        pendingDisplayRefreshTask = nil

        let nextDisplayQuotes = visibleQuoteKeys.reduce(into: [WealthBrokerQuoteKey: WealthBrokerQuote]()) { partial, key in
            guard let quote = rawQuotes[key] else { return }
            partial[key] = quote
        }
        guard nextDisplayQuotes != displayQuotes else { return }
        displayQuotes = nextDisplayQuotes
    }

    private func regionBucket(for market: String) -> String {
        switch WealthMarketLabels.region(for: market) {
        case "AU":
            return "AU"
        case "US":
            return "US"
        case "EU":
            return "EU"
        default:
            return "Other"
        }
    }
}
