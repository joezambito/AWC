import Foundation
import Combine

@MainActor
final class WealthMarketBrowserStore: ObservableObject {
    @Published var searchText = ""
    @Published var selectedAssetType = "ALL"
    @Published var selectedRegion = "ALL"
    @Published var selectedCountry = "ALL"
    @Published var selectedExchange = "ALL"
    @Published var selectedCurrency = "ALL"
    @Published var page = 0

    func options(for records: [MarketUniverseRecord], keyPath: KeyPath<MarketUniverseRecord, String>) -> [String] {
        let values = Set(
            records
                .map { $0[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        return ["ALL"] + values.sorted()
    }

    func filteredRecords(from records: [MarketUniverseRecord]) -> [MarketUniverseRecord] {
        records
            .filter(\.isActive)
            .filter { record in
                matchesFilter(record.assetType, selected: selectedAssetType)
                    && matchesFilter(record.region, selected: selectedRegion)
                    && matchesFilter(record.country, selected: selectedCountry)
                    && matchesFilter(record.exchange, selected: selectedExchange)
                    && matchesFilter(record.currency, selected: selectedCurrency)
                    && matchesSearch(record)
            }
    }

    func pageSize(hasDesktopLayout: Bool) -> Int {
        hasDesktopLayout ? 120 : 40
    }

    func pageCount(for records: [MarketUniverseRecord], hasDesktopLayout: Bool) -> Int {
        guard !records.isEmpty else { return 1 }
        return Int(ceil(Double(records.count) / Double(pageSize(hasDesktopLayout: hasDesktopLayout))))
    }

    func clampedPage(for records: [MarketUniverseRecord], hasDesktopLayout: Bool) -> Int {
        min(max(page, 0), max(pageCount(for: records, hasDesktopLayout: hasDesktopLayout) - 1, 0))
    }

    func pagedRecords(from records: [MarketUniverseRecord], hasDesktopLayout: Bool) -> [MarketUniverseRecord] {
        let size = pageSize(hasDesktopLayout: hasDesktopLayout)
        let startIndex = clampedPage(for: records, hasDesktopLayout: hasDesktopLayout) * size
        guard startIndex < records.count else { return [] }
        let endIndex = min(startIndex + size, records.count)
        return Array(records[startIndex..<endIndex])
    }

    func resultsLabel(for records: [MarketUniverseRecord], hasDesktopLayout: Bool) -> String {
        guard !records.isEmpty else { return "0 RESULTS" }
        let size = pageSize(hasDesktopLayout: hasDesktopLayout)
        let start = clampedPage(for: records, hasDesktopLayout: hasDesktopLayout) * size + 1
        let end = min(start + size - 1, records.count)
        return "\(start)-\(end) OF \(records.count)"
    }

    func resetPagination() {
        guard page != 0 else { return }
        page = 0
    }

    private func matchesFilter(_ value: String, selected: String) -> Bool {
        selected == "ALL" || value == selected
    }

    private func matchesSearch(_ record: MarketUniverseRecord) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let normalizedQuery = query.lowercased()
        return record.symbol.lowercased().contains(normalizedQuery)
            || record.name.lowercased().contains(normalizedQuery)
            || record.exchange.lowercased().contains(normalizedQuery)
            || record.country.lowercased().contains(normalizedQuery)
    }
}
