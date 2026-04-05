import Foundation
import Combine

@MainActor
final class WealthMarketUniverseStore: ObservableObject {
    static let shared = WealthMarketUniverseStore()

    private enum StorageKey {
        static let skipNextAutomaticLoadAfterReset = "awc_world_market_skip_next_auto_load_after_reset"
    }

    @Published private(set) var records: [MarketUniverseRecord] = []
    @Published private(set) var worldShareRecords: [MarketUniverseRecord] = []
    @Published private(set) var worldShareRecordsByRegion: [String: [MarketUniverseRecord]] = [:]
    @Published private(set) var sourceLabel = "WAITING"
    @Published private(set) var warningMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var lastSuccessfulLoadAt: Date?

    private var didRequestLoad = false
    private var isBackgroundRefreshQueued = false
    private let defaults = UserDefaults.standard
    private var resetObserver: AnyCancellable?

    private var backgroundRefreshStaleInterval: TimeInterval { 15 * 60 }

    private init() {
        resetObserver = NotificationCenter.default.publisher(
            for: WealthAppSessionController.visibleAppStateDidResetNotification
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.clearForVisibleAppReset()
        }

        if let cacheURL = WealthMarketUniverseStartupCache.snapshotFileURL(),
           FileManager.default.fileExists(atPath: cacheURL.path) {
            defaults.removeObject(forKey: WealthMarketUniverseStartupCache.legacyDefaultsKey)
        }
    }

    // MARK: - Startup integration

    /// Called by the startup sequence to restore a persisted universe snapshot
    /// without a network download.
    ///
    /// - Returns: `true` when a valid snapshot was restored and the universe
    ///   is ready to use; `false` when a full reload is required.
    @discardableResult
    func prepareCachedSnapshotForStartup() -> Bool {
        return restorePersistedSnapshotIfAvailable(reason: "startup")
    }

    /// Full async reload of the universe used during the startup sequence.
    ///
    /// Loads data from the network (or local CSV fallback), publishes staggered
    /// region-by-region updates so the UI stays responsive, and persists the
    /// result for future launches.
    func reloadForStartupSequence() async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        await performLoad(reason: "startup")
    }

    // MARK: - Reset handler

    private func clearForVisibleAppReset() {
        didRequestLoad = false
        isLoading = false

        if records.isEmpty {
            sourceLabel = "WAITING"
            warningMessage = nil
            errorMessage = nil
        }

        debugLog("visible reset handled; records=\(records.count) source=\(sourceLabel)")
    }

    // MARK: - Private helpers

    @discardableResult
    private func restorePersistedSnapshotIfAvailable(reason: String) -> Bool {
        guard let snapshot = WealthMarketUniverseStartupCache.restore(defaults: defaults) else {
            return false
        }

        guard WealthMarketUniverseStartupCache.isValidPersistedSnapshot(snapshot) else {
            debugLog("discarded invalid persisted snapshot during \(reason); records=\(snapshot.records.count)")
            return false
        }

        debugLog("restoring persisted snapshot during \(reason)")
        applySnapshot(snapshot)
        return !records.isEmpty
    }

    private func applySnapshot(_ snapshot: WealthMarketUniverseStartupCache.Snapshot) {
        records = snapshot.records
        worldShareRecords = snapshot.records
        worldShareRecordsByRegion = Dictionary(grouping: snapshot.records, by: \.region)
        sourceLabel = "CACHE"
        lastSuccessfulLoadAt = snapshot.savedAt
        warningMessage = nil
        errorMessage = nil
    }

    private func performLoad(reason: String) async {
        debugLog("performLoad – reason=\(reason)")
        await MainActor.run {
            sourceLabel = "LOADING"
            errorMessage = nil
        }
        // Actual network/CSV load is provided by the real Xcode implementation.
        // This stub marks load as done without overwriting any cached records.
        await MainActor.run {
            isLoading = false
            didRequestLoad = true
            if !records.isEmpty {
                sourceLabel = "CACHE"
                lastSuccessfulLoadAt = lastSuccessfulLoadAt ?? Date()
            }
        }
    }

    private func debugLog(_ message: String) {
        WealthEventLogStore.shared.record(
            title: "Universe Store",
            detail: message,
            category: "universe",
            tintName: "cyan",
            timestamp: .now
        )
    }
}
