import Foundation
import Combine

@MainActor
final class WealthMarketUniverseStore: ObservableObject {
    @Published private(set) var records: [MarketUniverseRecord] = []
    @Published private(set) var worldShareRecords: [MarketUniverseRecord] = []
    @Published private(set) var worldShareRecordsByRegion: [String: [MarketUniverseRecord]] = [:]
    @Published private(set) var sourceLabel = "WAITING"
    @Published private(set) var warningMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private var didRequestLoad = false

    func loadIfNeeded() {
        guard !didRequestLoad else { return }
        didRequestLoad = true
        reload()
    }

    func reload() {
        isLoading = true
        errorMessage = nil
        warningMessage = nil
        sourceLabel = "LOADING"

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.loadFreshUniverseSnapshot()
            }.value

            records = result.records.sorted(by: MarketUniverseRecord.browserOrder)
            worldShareRecords = WealthIBKRContractValidationStore.shared.cleanWorldMarketRecords(
                Self.quoteableWorldShareRecords(from: records)
            )
            worldShareRecordsByRegion = Dictionary(grouping: worldShareRecords, by: \.regionCode)
            sourceLabel = result.sourceLabel
            warningMessage = result.warningMessage
            errorMessage = result.errorMessage
            isLoading = false
        }
    }

    nonisolated private static func loadFreshUniverseSnapshot() -> MarketUniverseLoadResult {
        WealthMarketUniverseLoader.invalidateCache()
        return WealthMarketUniverseLoader.load()
    }

    private static func quoteableWorldShareRecords(from records: [MarketUniverseRecord]) -> [MarketUniverseRecord] {
        records
            .filter { $0.isWorldShareInstrument }
            .sorted(by: MarketUniverseRecord.browserOrder)
    }
}
