//
//  WealthMarketUniverseStore.swift
//  Wealth Creation
//
//  Universe Update 8/4/2026
//  The universe cache no longer re-downloads every time the app opens.
//  Once a valid cache is in memory or restored from disk the store
//  considers itself done.  A background refresh is only triggered when
//  there is genuinely no data yet (first install, reset, or the cache
//  is empty).  After a background load completes, the new records are
//  only applied and persisted when the incoming record count is different
//  from what is already cached – so the phone never does unnecessary
//  write work when the universe has not changed.
//

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

    // Background refresh is only needed when there is no cached data at all.
    // The 15-minute stale interval is no longer used to force re-downloads
    // when a valid cache already exists.
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

    func loadIfNeeded() {
        guard WealthEngineStore.shared.startupAllowsUniverseRefresh else { return }
        guard !didRequestLoad else {
            queueBackgroundRefreshIfNeeded(force: false, reason: "loadIfNeeded already requested")
            return
        }

        if defaults.bool(forKey: StorageKey.skipNextAutomaticLoadAfterReset) {
            defaults.removeObject(forKey: StorageKey.skipNextAutomaticLoadAfterReset)
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
            // Cache is valid – no background refresh needed.
            return
        }

        if restorePersistedSnapshotIfAvailable(reason: "loadIfNeeded") {
            sourceLabel = normalizedCachedSourceLabel(current: sourceLabel)
            errorMessage = nil
            debugLog("loadIfNeeded restored persisted snapshot; records=\(records.count) source=\(sourceLabel)")
            // Persisted cache was restored – no background refresh needed.
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
            // Cache is valid – no background refresh needed.
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
        // Persisted cache was restored – no background refresh needed.
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
            // Cache is valid – no background refresh needed.
            return
        }

        if restorePersistedSnapshotIfAvailable(reason: "startup-sequence") {
            isLoading = false
            errorMessage = nil
            warningMessage = nil
            sourceLabel = normalizedCachedSourceLabel(current: sourceLabel)
            debugLog("startup sequence restored persisted snapshot; records=\(records.count) source=\(sourceLabel)")
            // Persisted cache was restored – no background refresh needed.
            return
        }

        await performRefresh(forceForegroundLoading: true)
    }

    nonisolated private static func loadFreshUniverseSnapshot() -> MarketUniverseLoadResult {
        WealthMarketUniverseLoader.load()
    }

    private static func quoteableWorldShareRecords(from records: [MarketUniverseRecord]) -> [MarketUniverseRecord] {
        records
            .filter { $0.isWorldShareInstrument }
            .sorted(by: MarketUniverseRecord.browserOrder)
    }

    private var hasUsableInMemorySnapshot: Bool {
        !records.isEmpty
    }

    private func normalizedCachedSourceLabel(current: String) -> String {
        current == "WAITING" || current == "LOADING" ? "CACHED SNAPSHOT" : current
    }

    // Only trigger a background refresh when there are genuinely no records
    // (first install or hard reset).  If a valid cache is present, no
    // background refresh is needed – the universe only re-downloads when
    // the incoming record count differs from the cached count.
    private func shouldBackgroundRefresh(force: Bool) -> Bool {
        if force { return true }
        guard !isLoading else { return false }
        guard records.isEmpty else { return false }
        return true
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
        let fullSortedRecords = snapshot.records.sorted(by: MarketUniverseRecord.browserOrder)
        let publishedWorldRecords = publishedWorldShareRecords(from: fullSortedRecords)

        records = fullSortedRecords
        worldShareRecords = publishedWorldRecords
        worldShareRecordsByRegion = Dictionary(grouping: publishedWorldRecords, by: \.regionCode)
        sourceLabel = snapshot.sourceLabel
        lastSuccessfulLoadAt = snapshot.lastSuccessfulLoadAt
        warningMessage = snapshot.warningMessage
        errorMessage = snapshot.errorMessage
        debugLog("applied snapshot; records=\(records.count) world=\(worldShareRecords.count) source=\(sourceLabel)")
    }

    private func applyStagedRefresh(_ result: MarketUniverseLoadResult) async {
        let canonicalRecords = result.records.sorted(by: MarketUniverseRecord.browserOrder)
        let publishedWorldRecords = publishedWorldShareRecords(from: canonicalRecords)

        if publishedWorldRecords.isEmpty, !records.isEmpty {
            sourceLabel = normalizedCachedSourceLabel(current: sourceLabel)
            warningMessage = result.warningMessage
            errorMessage = result.errorMessage
            isLoading = false
            debugLog("refresh returned empty/error; kept cached records=\(records.count) source=\(sourceLabel)")
            return
        }

        let nextRegions = Dictionary(grouping: publishedWorldRecords, by: \.regionCode)
        let orderedRegions = Self.stagedRegionOrder(for: nextRegions.keys)

        var stagedRegions = worldShareRecordsByRegion
        let hadExistingData = !stagedRegions.isEmpty

        if !hadExistingData {
            records = canonicalRecords
        }

        for batchStart in stride(from: 0, to: orderedRegions.count, by: 2) {
            let batchEnd = min(batchStart + 2, orderedRegions.count)
            let batchRegions = orderedRegions[batchStart..<batchEnd]

            for region in batchRegions {
                stagedRegions[region] = nextRegions[region] ?? []
            }

            worldShareRecordsByRegion = stagedRegions
            worldShareRecords = stagedRegions.values
                .flatMap { $0 }
                .sorted(by: MarketUniverseRecord.browserOrder)

            if hadExistingData {
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }

        for region in Set(stagedRegions.keys).subtracting(Set(nextRegions.keys)) {
            stagedRegions.removeValue(forKey: region)
        }

        worldShareRecordsByRegion = stagedRegions
        worldShareRecords = stagedRegions.values
            .flatMap { $0 }
            .sorted(by: MarketUniverseRecord.browserOrder)

        records = canonicalRecords
        sourceLabel = result.sourceLabel
        lastSuccessfulLoadAt = Date()
        warningMessage = result.warningMessage
        errorMessage = result.errorMessage
        isLoading = false
        debugLog("refresh finished; merged records=\(records.count) world=\(worldShareRecords.count) source=\(sourceLabel)")

        WealthMarketUniverseStartupCache.persist(
            records: canonicalRecords,
            sourceLabel: result.sourceLabel,
            lastSuccessfulLoadAt: lastSuccessfulLoadAt,
            warningMessage: result.warningMessage,
            errorMessage: result.errorMessage,
            defaults: defaults
        )
    }

    // A background load only updates the cache when the incoming record
    // count is different from what is already in memory.  If the count
    // is the same the universe has not changed and the existing cache is
    // kept without any disk write or repaint.
    private func persistBackgroundSnapshotIfPossible(_ result: MarketUniverseLoadResult) -> Bool {
        guard !records.isEmpty else { return false }

        let canonicalRecords = result.records.sorted(by: MarketUniverseRecord.browserOrder)
        let publishedWorldRecords = publishedWorldShareRecords(from: canonicalRecords)
        guard !publishedWorldRecords.isEmpty else {
            isLoading = false
            debugLog("background refresh kept visible snapshot after empty/error result; records=\(records.count) source=\(sourceLabel)")
            return true
        }

        // If the loaded record count matches what we already have, nothing
        // has changed in the universe – skip the persist and stay silent.
        guard canonicalRecords.count != records.count else {
            isLoading = false
            debugLog("background refresh skipped; record count unchanged (cached=\(records.count) loaded=\(canonicalRecords.count))")
            return true
        }

        WealthMarketUniverseStartupCache.persist(
            records: canonicalRecords,
            sourceLabel: result.sourceLabel,
            lastSuccessfulLoadAt: Date(),
            warningMessage: result.warningMessage,
            errorMessage: result.errorMessage,
            defaults: defaults
        )
        isLoading = false
        debugLog("background refresh persisted snapshot without repaint; visible records=\(records.count) refreshed=\(canonicalRecords.count)")
        return true
    }

    nonisolated private static func stagedRegionOrder<S: Sequence>(for regions: S) -> [String] where S.Element == String {
        let preferred = ["US", "CA", "EU", "APAC", "ME", "LATAM", "AFRICA", "AU", "FX", "CRYPTO", "GLOBAL", "UNKNOWN"]
        let available = Set(regions)
        let orderedPreferred = preferred.filter { available.contains($0) }
        let remainder = available.subtracting(preferred).sorted()
        return orderedPreferred + remainder
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

    private func publishedWorldShareRecords(from records: [MarketUniverseRecord]) -> [MarketUniverseRecord] {
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
