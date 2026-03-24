import SwiftUI

extension MarketsView {
    var assetTypeOptions: [String] {
        browserStore.options(for: universeStore.records, keyPath: \.assetType)
    }

    var regionOptions: [String] {
        browserStore.options(for: universeStore.records, keyPath: \.region)
    }

    var countryOptions: [String] {
        browserStore.options(for: universeStore.records, keyPath: \.country)
    }

    var exchangeOptions: [String] {
        browserStore.options(for: universeStore.records, keyPath: \.exchange)
    }

    var currencyOptions: [String] {
        browserStore.options(for: universeStore.records, keyPath: \.currency)
    }

    var filteredBrowserRecords: [MarketUniverseRecord] {
        browserStore.filteredRecords(from: universeStore.records)
    }

    var pagedBrowserRecords: [MarketUniverseRecord] {
        browserStore.pagedRecords(from: filteredBrowserRecords, hasDesktopLayout: hasDesktopLayout)
    }

    var browserResultsLabel: String {
        browserStore.resultsLabel(for: filteredBrowserRecords, hasDesktopLayout: hasDesktopLayout)
    }

    var browserPageCount: Int {
        browserStore.pageCount(for: filteredBrowserRecords, hasDesktopLayout: hasDesktopLayout)
    }

    var clampedBrowserPage: Int {
        browserStore.clampedPage(for: filteredBrowserRecords, hasDesktopLayout: hasDesktopLayout)
    }
}
