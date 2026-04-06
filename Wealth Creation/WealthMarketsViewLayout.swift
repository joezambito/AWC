import SwiftUI

extension MarketsView {
    // MARK: Subscription Tuning
    private var desktopSeededRegionCount: Int { 3 }
    private var desktopSeededRegionSliceSize: Int { 48 }
    private var desktopExpandedRegionSliceSize: Int { 160 }
    private var desktopFallbackSubscriptionCount: Int { 120 }
    private var desktopExpandedBucketBufferCount: Int { 20 }
    private var desktopExpandedBucketMinimumCount: Int { 80 }

    // MARK: Lifecycle
    func handleAppear() {
        expandedMarketRegion = nil
        expandedMarketBucket = nil
        visibleMarketBucketCount = 50
        persistedExpandedMarketRegion = ""
        persistedExpandedMarketBucket = ""
        persistedVisibleMarketBucketCount = 50

        if hasDesktopLayout {
            prepareSharedMarketFeedInputs()
            prepareMarketBoardContent()
            syncMarketViewCycleSelection()
            syncVisibleMarketQuoteScope()
        } else {
            guard engine.startupPostSequenceReady else {
                quoteStore.setVisibleQuoteKeys([])
                return
            }
            syncMarketViewCycleSelection()
            syncVisibleMarketQuoteScope()
        }

        guard hasDesktopLayout else { return }

        let stale = engine.lastRefresh.map { Date().timeIntervalSince($0) > 75 } ?? true
        deferredMarketsStartupTask?.cancel()
        deferredMarketsStartupTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            guard engine.startupPostSequenceReady else { return }

            if stale || engine.rankedAssets.isEmpty {
                await engine.refreshAsync(mode: .soft)
                guard !Task.isCancelled else { return }
            }

            prepareSharedMarketFeedInputs()
            prepareMarketBoardContent()
            syncMarketViewCycleSelection()
            syncVisibleMarketQuoteScope()
            universeStore.loadIfNeeded()
            subscribeImportedUniverseIfNeeded()
        }
    }

    func subscribeImportedUniverseIfNeeded() {
        guard hasDesktopLayout else {
            lastPreparedImportedUniverseIDs = []
            lastPreparedImportedUniverseBrokerConnected = false
            lastPreparedImportedUniverseDelayedQuotes = true
            return
        }
        guard engine.startupPostSequenceReady else { return }
        let importedUniverse = prioritizedImportedUniverseSubscriptionRecords
        let brokerConnected = syncStore.isTWSConnectedForQuotes
        let delayedQuotes = WealthProtectionSettingsStore.shared.demoMode || !syncStore.liveMode
        guard !importedUniverse.isEmpty else {
            lastPreparedImportedUniverseIDs = []
            lastPreparedImportedUniverseBrokerConnected = brokerConnected
            lastPreparedImportedUniverseDelayedQuotes = delayedQuotes
            return
        }
        let preparedIDs = importedUniverse.map(\.id)
        guard
            preparedIDs != lastPreparedImportedUniverseIDs ||
            brokerConnected != lastPreparedImportedUniverseBrokerConnected ||
            delayedQuotes != lastPreparedImportedUniverseDelayedQuotes
        else { return }
        lastPreparedImportedUniverseIDs = preparedIDs
        lastPreparedImportedUniverseBrokerConnected = brokerConnected
        lastPreparedImportedUniverseDelayedQuotes = delayedQuotes
        quoteStore.prepareSubscriptions(for: importedUniverse)
    }

    // MARK: Phone Cycle
    func startPhoneMarketCycle() {
        guard !hasDesktopLayout else {
            phoneMarketCycleTask?.cancel()
            phoneMarketCycleStage = 2
            syncVisibleMarketQuoteScope()
            return
        }

        phoneMarketCycleTask?.cancel()
        phoneMarketCycleTask = Task { @MainActor in
            phoneMarketCycleStage = 0
            marketFeedScanBatchIndex = 0

            await Task.yield()
            guard !Task.isCancelled else { return }
            phoneMarketCycleStage = 1

            await Task.yield()
            guard !Task.isCancelled else { return }
            phoneMarketCycleStage = 2
        }
    }

    func marketRegionIsActive(_ region: String) -> Bool {
        if hasDesktopLayout { return true }

        switch region {
        case "GLOBAL":
            return phoneMarketCycleStage >= 1
        case "UNKNOWN":
            return phoneMarketCycleStage >= 2
        default:
            return true
        }
    }

    // MARK: Subscription Selection
    private var prioritizedImportedUniverseSubscriptionRecords: [MarketUniverseRecord] {
        guard hasDesktopLayout else { return quoteableWorldShareRecords }

        let seededRecords = desktopSeededSubscriptionRecords

        if !seededRecords.isEmpty {
            return Array(seededRecords)
        }

        return Array(quoteableWorldShareRecords.prefix(desktopFallbackSubscriptionCount))
    }

    private var desktopSeededSubscriptionRecords: [MarketUniverseRecord] {
        let seededRegions = Array(preparedSnapshot.marketsBoardSummaries.prefix(desktopSeededRegionCount).map(\.region))
        return seededRegions.flatMap { region in
            importedMarketRecords(for: region)
                .sorted(by: MarketUniverseRecord.browserOrder)
                .prefix(desktopSeededRegionSliceSize)
        }
    }

    var phoneBody: some View {
        VStack(spacing: 8) {
            phoneTop100MarketsPanel
        }
    }

    func desktopBody(isWide: Bool) -> some View {
        worldMarketsPanel
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
