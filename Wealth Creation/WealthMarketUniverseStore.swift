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
        let note = WealthAppSessionController.visibleAppStateDidResetNotification
        resetObserver = NotificationCenter.default
            .publisher(for: note)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.clearForVisibleAppReset() }

        let legacyKey = WealthMarketUniverseStartupCache.legacyDefaultsKey
        if let url = WealthMarketUniverseStartupCache.snapshotFileURL(),
           FileManager.default.fileExists(atPath: url.path) {
            defaults.removeObject(forKey: legacyKey)
        }
    }

    func loadIfNeeded() {
        guard WealthEngineStore.shared.startupAllowsUniverseRefresh else { return }

        guard !didRequestLoad else {
            queueBackgroundRefreshIfNeeded(force: false, reason: "loadIfNeeded already requested")
            return
        }

        let resetKey = StorageKey.skipNextAutomaticLoadAfterReset
        if defaults.bool(forKey: resetKey) {
            defaults.removeObject(forKey: resetKey)
            didRequestLoad = true
            debugLog("skip automatic load after reset; preserved records=\(records.count)")
            queueBackgroundRefreshIfNeeded(force: false, reason: "post-reset preserve")
            return
        }

        didRequestLoad = true

        if hasUsableInMemorySnapshot {
            sourceLabel = normalizedCachedSourceLabel(current: sourceLabel)
            errorMessage = nil
            warningMessage = nil
            debugLog("loadIfNeeded reusing in-memory snapshot; records=\(records.count) source=\(sourceLabel)")
            queueBackgroundRefreshIfNeeded(force: false, reason: "in-memory snapshot")
            return
        }

        if restorePersistedSnapshotIfAvailable(reason: "loadIfNeeded") {
            sourceLabel = normalizedCachedSourceLabel(current: sourceLabel)
            errorMessage = nil
            debugLog("loadIfNeeded restored persisted snapshot; records=\(records.count) source=\(sourceLabel)")
            queueBackgroundRefreshIfNeeded(force: false, reason: "restored snapshot")
            return
        }

        debugLog("loadIfNeeded found no cache; performing foreground reload")
        reload()
    }

    static func prepareForVisibleAppReset(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: StorageKey.skipNextAutomaticLoadAfterReset)
    }

    func reload() {
        guard WealthEngineStore.shared.startupAllowsUniverseRefresh else { return }
        Task { @MainActor [weak self] in
            await self?.performRefresh(forceForegroundLoading: true)
        }
    }

    func reloadAsync() async {
        guard WealthEngineStore.shared.startupAllowsUniverseRefresh else { return }
        await performRefresh(forceForegroundLoading: true)
    }

    func prepareCachedSnapshotForStartup() -> Bool {
        didRequestLoad = true

        if hasUsableInMemorySnapshot {
            isLoading = false
            errorMessage = nil
            warningMessage = nil
            sourceLabel = normalizedCachedSourceLabel(current: sourceLabel)
            debugLog("startup cache prepare reused in-memory snapshot; records=\(records.count) source=\(sourceLabel)")
            queueBackgroundRefreshIfNeeded(force: false, reason: "startup in-memory")
            return true
        }

        guard restorePersistedSnapshotIfAvailable(reason: "startup-cache-prepare") else {
            return false
        }

        isLoading = false
        errorMessage = nil
        warningMessage = nil
        sourceLabel = normalizedCachedSourceLabel(current: sourceLabel)
        debugLog("startup cache prepare restored persisted snapshot; records=\(records.count) source=\(sourceLabel)")
        queueBackgroundRefreshIfNeeded(force: false, reason: "startup persisted")
        return true
    }

    func reloadForStartupSequence() async {
        didRequestLoad = true

        if hasUsableInMemorySnapshot {
            isLoading = false
            errorMessage = nil
            warningMessage = nil
            sourceLabel = normalizedCachedSourceLabel(current: sourceLabel)
            debugLog("startup sequence reused in-memory snapshot; records=\(records.count) source=\(sourceLabel)")
            queueBackgroundRefreshIfNeeded(force: false, reason: "startup sequence in-memory")
            return
        }

        if restorePersistedSnapshotIfAvailable(reason: "startup-sequence") {
            isLoading = false
            errorMessage = nil
            warningMessage = nil
            sourceLabel = normalizedCachedSourceLabel(current: sourceLabel)
            debugLog("startup sequence restored persisted snapshot; records=\(records.count) source=\(sourceLabel)")
            queueBackgroundRefreshIfNeeded(force: false, reason: "startup sequence persisted")
            return
        }

        await performRefresh(forceForegroundLoading: true)
    }

    nonisolated private static func loadFreshUniverseSnapshot() -> MarketUniverseLoadResult {
        WealthMarketUniverseLoader.load()
    }

    private static func quoteableWorldShareRecords(
        from records: [MarketUniverseRecord]
    ) -> [MarketUniverseRecord] {
        records
            .filter { $0.isWorldShareInstrument }
            .sorted(by: MarketUniverseRecord.browserOrder)
    }

    private var hasUsableInMemorySnapshot: Bool { !records.isEmpty }

    private func normalizedCachedSourceLabel(current: String) -> String {
        (current == "WAITING" || current == "LOADING") ? "CACHED SNAPSHOT" : current
    }

    private func shouldBackgroundRefresh(force: Bool) -> Bool {
        if force { return true }
        guard !isLoading else { return false }
        guard !records.isEmpty else { return true }
        guard let lastSuccessfulLoadAt else { return true }
        return Date().timeIntervalSince(lastSuccessfulLoadAt) >= backgroundRefreshStaleInterval
    }

    private func queueBackgroundRefreshIfNeeded(force: Bool, reason: String) {
        guard WealthEngineStore.shared.startupAllowsUniverseRefresh else { return }
        guard shouldBackgroundRefresh(force: force) else { return }
        guard !isBackgroundRefreshQueued else { return }

        isBackgroundRefreshQueued = true
        debugLog("queueing background refresh; reason=\(reason) records=\(records.count)")

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(forceForegroundLoading: false)
        }
    }

    private func performRefresh(forceForegroundLoading: Bool) async {
        defer { isBackgroundRefreshQueued = false }

        if forceForegroundLoading || records.isEmpty {
            isLoading = true
            sourceLabel = records.isEmpty ? "LOADING" : "REFRESHING • \(sourceLabel)"
        } else {
            isLoading = false
            sourceLabel = normalizedCachedSourceLabel(current: sourceLabel)
        }

        errorMessage = nil
        warningMessage = nil
        debugLog("refresh started; records=\(records.count) source=\(sourceLabel)")

        let result = await Task.detached(priority: .userInitiated) {
            Self.loadFreshUniverseSnapshot()
        }.value

        if !forceForegroundLoading && persistBackgroundSnapshotIfPossible(result) {
            return
        }

        await applyStagedRefresh(result)
    }

    private func applySnapshot(_ snapshot: WealthStoredUniverseSnapshot) {
        let sorted = snapshot.records.sorted(by: MarketUniverseRecord.browserOrder)
        let worldRecords = publishedWorldShareRecords(from: sorted)

        records = sorted
        worldShareRecords = worldRecords
        worldShareRecordsByRegion = Dictionary(grouping: worldRecords, by: \.regionCode)
        sourceLabel = snapshot.sourceLabel
        lastSuccessfulLoadAt = snapshot.lastSuccessfulLoadAt
        warningMessage = snapshot.warningMessage
        errorMessage = snapshot.errorMessage
        debugLog("applied snapshot; records=\(records.count) world=\(worldShareRecords.count) source=\(sourceLabel)")
    }

    private func applyStagedRefresh(_ result: MarketUniverseLoadResult) async {
        let canonical = result.records.sorted(by: MarketUniverseRecord.browserOrder)
        let worldRecords = publishedWorldShareRecords(from: canonical)

        if worldRecords.isEmpty, !records.isEmpty {
            sourceLabel = normalizedCachedSourceLabel(current: sourceLabel)
            warningMessage = result.warningMessage
            errorMessage = result.errorMessage
            isLoading = false
            debugLog("refresh returned empty/error; kept cached records=\(records.count) source=\(sourceLabel)")
            return
        }

        let nextByRegion = Dictionary(grouping: worldRecords, by: \.regionCode)
        let regionOrder = Self.stagedRegionOrder(for: nextByRegion.keys)

        var staged = worldShareRecordsByRegion
        let hadExistingData = !staged.isEmpty

        if !hadExistingData { records = canonical }

        for batchStart in stride(from: 0, to: regionOrder.count, by: 2) {
            let batchEnd = min(batchStart + 2, regionOrder.count)
            for region in regionOrder[batchStart..<batchEnd] {
                staged[region] = nextByRegion[region] ?? []
            }
            worldShareRecordsByRegion = staged
            worldShareRecords = staged.values
                .flatMap { $0 }
                .sorted(by: MarketUniverseRecord.browserOrder)
            if hadExistingData {
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }

        for region in Set(staged.keys).subtracting(Set(nextByRegion.keys)) {
            staged.removeValue(forKey: region)
        }

        worldShareRecordsByRegion = staged
        worldShareRecords = staged.values
            .flatMap { $0 }
            .sorted(by: MarketUniverseRecord.browserOrder)

        records = canonical
        sourceLabel = result.sourceLabel
        lastSuccessfulLoadAt = Date()
        warningMessage = result.warningMessage
        errorMessage = result.errorMessage
        isLoading = false
        debugLog("refresh finished; merged records=\(records.count) world=\(worldShareRecords.count) source=\(sourceLabel)")

        WealthMarketUniverseStartupCache.persist(
            records: canonical,
            sourceLabel: result.sourceLabel,
            lastSuccessfulLoadAt: lastSuccessfulLoadAt,
            warningMessage: result.warningMessage,
            errorMessage: result.errorMessage,
            defaults: defaults
        )
    }

    private func persistBackgroundSnapshotIfPossible(_ result: MarketUniverseLoadResult) -> Bool {
        guard !records.isEmpty else { return false }

        let canonical = result.records.sorted(by: MarketUniverseRecord.browserOrder)
        let worldRecords = publishedWorldShareRecords(from: canonical)

        guard !worldRecords.isEmpty else {
            isLoading = false
            debugLog("background refresh kept visible snapshot after empty/error result; records=\(records.count) source=\(sourceLabel)")
            return true
        }

        WealthMarketUniverseStartupCache.persist(
            records: canonical,
            sourceLabel: result.sourceLabel,
            lastSuccessfulLoadAt: Date(),
            warningMessage: result.warningMessage,
            errorMessage: result.errorMessage,
            defaults: defaults
        )
        isLoading = false
        debugLog("background refresh persisted snapshot without repaint; visible records=\(records.count) refreshed=\(canonical.count)")
        return true
    }

    nonisolated private static func stagedRegionOrder<S: Sequence>(
        for regions: S
    ) -> [String] where S.Element == String {
        let preferred = ["US", "CA", "EU", "APAC", "ME", "LATAM", "AFRICA", "AU", "FX", "CRYPTO", "GLOBAL", "UNKNOWN"]
        let available = Set(regions)
        let head = preferred.filter { available.contains($0) }
        let tail = available.subtracting(preferred).sorted()
        return head + tail
    }

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

    private func publishedWorldShareRecords(
        from records: [MarketUniverseRecord]
    ) -> [MarketUniverseRecord] {
        WealthIBKRContractValidationStore.shared.cleanWorldMarketRecords(
            Self.quoteableWorldShareRecords(from: records)
        )
    }

    private func scopedUniverseRecords(_ records: [MarketUniverseRecord]) -> [MarketUniverseRecord] {
        records
    }

    private func debugLog(_ message: String) {
#if DEBUG
        if WealthPipelineTraceLogger.isEnabledForDebugOutput {
            print("[WorldMarketStore] \(message)")
        }
#endif
    }
}
