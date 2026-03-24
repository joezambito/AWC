import SwiftUI

extension MarketsView {
    func handleAppear() {
        let stale = engine.lastRefresh.map { Date().timeIntervalSince($0) > 75 } ?? true
        if stale || engine.rankedAssets.isEmpty {
            engine.refresh(mode: .soft)
        }

        startPhoneMarketCycle()
        universeStore.loadIfNeeded()
        subscribeImportedUniverseIfNeeded()
    }

    func subscribeImportedUniverseIfNeeded() {
        let importedUniverse = prioritizedImportedUniverseRecords
        guard !importedUniverse.isEmpty else { return }
        quoteStore.prepareSubscriptions(for: importedUniverse)
    }

    func startPhoneMarketCycle() {
        guard !hasDesktopLayout else {
            phoneMarketCycleTask?.cancel()
            phoneMarketCycleStage = 2
            return
        }

        phoneMarketCycleTask?.cancel()
        phoneMarketCycleTask = Task { @MainActor in
            phoneMarketCycleStage = 0
            marketFeedScanBatchIndex = 0

            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            phoneMarketCycleStage = 1

            try? await Task.sleep(nanoseconds: 1_500_000_000)
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

    private var prioritizedImportedUniverseRecords: [MarketUniverseRecord] {
        guard !hasDesktopLayout else { return quoteableWorldShareRecords }

        let visibleKeys = Set(importedMarketRecordsForCurrentBatch.map(\.id))
        let deferredRecords = quoteableWorldShareRecords.filter { !visibleKeys.contains($0.id) }
        return importedMarketRecordsForCurrentBatch + deferredRecords
    }

    var phoneBody: some View {
        VStack(spacing: 8) {
            marketTogglePanel(title: "MARKET UNIVERSE", toggles: marketToggles)
            marketTogglePanel(title: "MARKET THEMES", toggles: themeToggles)
            capitalRoutingPanel
            regionalCalendarPanel
            worldMarketsPanel
        }
    }

    func desktopBody(isWide: Bool) -> some View {
        VStack(spacing: 10) {
            sectionShell(title: "MARKETS", subtitle: "Live world feed and routing", trailing: universeStore.sourceLabel)

            if isWide {
                HStack(alignment: .top, spacing: 10) {
                    marketTogglePanel(title: "MARKET UNIVERSE", toggles: marketToggles)
                    marketTogglePanel(title: "MARKET THEMES", toggles: themeToggles)
                }
            } else {
                marketTogglePanel(title: "MARKET UNIVERSE", toggles: marketToggles)
                marketTogglePanel(title: "MARKET THEMES", toggles: themeToggles)
            }

            if isWide {
                HStack(alignment: .top, spacing: 10) {
                    capitalRoutingPanel
                        .frame(maxWidth: .infinity, alignment: .top)
                    marketDesktopRail
                        .frame(maxWidth: 300, alignment: .top)
                }
            } else {
                capitalRoutingPanel
            }

            regionalCalendarPanel

            if isWide {
                HStack(alignment: .top, spacing: 10) {
                    worldMarketsPanel
                    snapshotPanel
                }
            } else {
                worldMarketsPanel
                snapshotPanel
            }

            instrumentBrowserPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
