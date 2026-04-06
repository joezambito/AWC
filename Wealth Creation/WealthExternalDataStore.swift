import Combine
import Foundation
import SwiftUI

@MainActor
final class WealthExternalDataStore: ObservableObject {
    static let shared = WealthExternalDataStore()

    @Published var optionsFlowEnabled: Bool
    @Published var darkPoolEnabled: Bool
    @Published var insiderEnabled: Bool
    @Published var filing13FEnabled: Bool
    @Published var earningsCalendarEnabled: Bool
    @Published var macroCalendarEnabled: Bool
    @Published var liveOutcomeLearningEnabled: Bool
    @Published var backtestEngineEnabled: Bool
    @Published var retrainingEnabled: Bool
    @Published var researchMeshEnabled: Bool
    @Published private(set) var researchSnapshotsByKey: [String: WealthExternalResearchSnapshot]
    @Published private(set) var sourceStatesByKind: [WealthExternalResearchKind: WealthExternalSignalState]
    @Published private(set) var sourceUpdatedAtByKind: [WealthExternalResearchKind: Date]
    @Published private(set) var sourceDetailByKind: [WealthExternalResearchKind: String]
    @Published private(set) var lastResearchRefreshAt: Date?
    @Published private(set) var configuredEndpointURLsByKind: [WealthExternalResearchKind: URL]
    @Published private(set) var providerModesByKind: [WealthExternalResearchKind: WealthExternalProviderMode]

    private enum StorageKey {
        static let persistedResearchStateVersion = "awc_provider_research_state_version"
        static let optionsFlowEnabled = "awc_provider_options_flow_enabled"
        static let darkPoolEnabled = "awc_provider_dark_pool_enabled"
        static let insiderEnabled = "awc_provider_insider_enabled"
        static let filing13FEnabled = "awc_provider_13f_enabled"
        static let earningsCalendarEnabled = "awc_provider_earnings_enabled"
        static let macroCalendarEnabled = "awc_provider_macro_enabled"
        static let liveOutcomeLearningEnabled = "awc_provider_outcome_enabled"
        static let backtestEngineEnabled = "awc_provider_backtest_enabled"
        static let retrainingEnabled = "awc_provider_retraining_enabled"
        static let researchMeshEnabled = "awc_provider_research_mesh_enabled"
        static let researchSnapshots = "awc_provider_research_snapshots_v1"
        static let sourceStates = "awc_provider_source_states_v1"
        static let sourceUpdatedAt = "awc_provider_source_updated_at_v1"
        static let sourceDetails = "awc_provider_source_details_v1"
        static let lastResearchRefreshAt = "awc_provider_last_research_refresh_at_v1"
    }

    private enum CacheConstants {
        static let persistedResearchStateVersion = 2
        static let researchSnapshotFileName = "provider_research_snapshots_v1.json"
        static let legacyMockProviderEndpoint = "http://127.0.0.1:8765"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.invalidatePersistedResearchStateIfNeeded(defaults: defaults)
        Self.sanitizeProviderEndpointsIfNeeded(defaults: defaults)
        optionsFlowEnabled = defaults.object(forKey: StorageKey.optionsFlowEnabled) as? Bool ?? true
        darkPoolEnabled = defaults.object(forKey: StorageKey.darkPoolEnabled) as? Bool ?? true
        insiderEnabled = defaults.object(forKey: StorageKey.insiderEnabled) as? Bool ?? true
        filing13FEnabled = defaults.object(forKey: StorageKey.filing13FEnabled) as? Bool ?? true
        earningsCalendarEnabled = defaults.object(forKey: StorageKey.earningsCalendarEnabled) as? Bool ?? true
        macroCalendarEnabled = defaults.object(forKey: StorageKey.macroCalendarEnabled) as? Bool ?? true
        liveOutcomeLearningEnabled = defaults.object(forKey: StorageKey.liveOutcomeLearningEnabled) as? Bool ?? true
        backtestEngineEnabled = defaults.object(forKey: StorageKey.backtestEngineEnabled) as? Bool ?? true
        retrainingEnabled = defaults.object(forKey: StorageKey.retrainingEnabled) as? Bool ?? true
        researchMeshEnabled = defaults.object(forKey: StorageKey.researchMeshEnabled) as? Bool ?? true
        researchSnapshotsByKey = Self.loadResearchSnapshots(from: defaults)
        sourceStatesByKind = Self.loadSourceStates(from: defaults)
        sourceUpdatedAtByKind = Self.loadSourceDates(from: defaults)
        sourceDetailByKind = Self.loadSourceDetails(from: defaults)
        lastResearchRefreshAt = defaults.object(forKey: StorageKey.lastResearchRefreshAt) as? Date
        configuredEndpointURLsByKind = Self.loadConfiguredEndpoints(from: defaults)
        providerModesByKind = Self.loadProviderModes(from: defaults)
        if Self.researchSnapshotFileURL().flatMap({ FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }) != nil {
            defaults.removeObject(forKey: StorageKey.researchSnapshots)
        }
    }

    func persist() {
        defaults.set(optionsFlowEnabled, forKey: StorageKey.optionsFlowEnabled)
        defaults.set(darkPoolEnabled, forKey: StorageKey.darkPoolEnabled)
        defaults.set(insiderEnabled, forKey: StorageKey.insiderEnabled)
        defaults.set(filing13FEnabled, forKey: StorageKey.filing13FEnabled)
        defaults.set(earningsCalendarEnabled, forKey: StorageKey.earningsCalendarEnabled)
        defaults.set(macroCalendarEnabled, forKey: StorageKey.macroCalendarEnabled)
        defaults.set(liveOutcomeLearningEnabled, forKey: StorageKey.liveOutcomeLearningEnabled)
        defaults.set(backtestEngineEnabled, forKey: StorageKey.backtestEngineEnabled)
        defaults.set(retrainingEnabled, forKey: StorageKey.retrainingEnabled)
        defaults.set(researchMeshEnabled, forKey: StorageKey.researchMeshEnabled)
        persistResearchState()
    }

    func normalizedSignal(for blueprint: OpportunityBlueprint) -> WealthNormalizedExternalSignal {
        let key = researchKey(for: blueprint)
        let snapshot = researchSnapshotsByKey[key]

        return activeFeedClients().reduce(WealthNormalizedExternalSignal.zero) { partial, client in
            if let stored = snapshot?.source(for: client.kind) {
                return partial.applying(stored.value, for: client.kind)
            }
            let fallback = client.signal(for: blueprint)
            return partial.applying(fallback.value(for: client.kind), for: client.kind)
        }
    }

    func activeFeedClients() -> [any WealthExternalFeedClient] {
        var clients: [any WealthExternalFeedClient] = []
        if optionsFlowEnabled { clients.append(WealthOptionsFlowFeedClient()) }
        if darkPoolEnabled { clients.append(WealthDarkPoolFeedClient()) }
        if insiderEnabled { clients.append(WealthInsiderFeedClient()) }
        if filing13FEnabled { clients.append(WealthFiling13FFeedClient()) }
        if earningsCalendarEnabled { clients.append(WealthEarningsFeedClient()) }
        if macroCalendarEnabled { clients.append(WealthMacroFeedClient()) }
        return clients
    }

    func isEnabled(_ kind: WealthExternalResearchKind) -> Bool {
        switch kind {
        case .optionsFlow: return optionsFlowEnabled
        case .darkPool: return darkPoolEnabled
        case .insider: return insiderEnabled
        case .filing13F: return filing13FEnabled
        case .earningsCalendar: return earningsCalendarEnabled
        case .macroCalendar: return macroCalendarEnabled
        }
    }

    func endpoint(for kind: WealthExternalResearchKind) -> URL? {
        configuredEndpointURLsByKind[kind]
    }

    func hasConfiguredEndpoint(for kind: WealthExternalResearchKind) -> Bool {
        configuredEndpointURLsByKind[kind] != nil
    }

    func mode(for kind: WealthExternalResearchKind) -> WealthExternalProviderMode {
        providerModesByKind[kind] ?? .liveEndpoint
    }

    func setMode(_ mode: WealthExternalProviderMode, for kind: WealthExternalResearchKind) {
        defaults.set(mode.rawValue, forKey: kind.modeStorageKey)
        providerModesByKind[kind] = mode
    }

    func setEnabled(_ enabled: Bool, for kind: WealthExternalResearchKind) {
        switch kind {
        case .optionsFlow:
            optionsFlowEnabled = enabled
        case .darkPool:
            darkPoolEnabled = enabled
        case .insider:
            insiderEnabled = enabled
        case .filing13F:
            filing13FEnabled = enabled
        case .earningsCalendar:
            earningsCalendarEnabled = enabled
        case .macroCalendar:
            macroCalendarEnabled = enabled
        }
        persist()
    }

    func researchKey(for blueprint: OpportunityBlueprint) -> String {
        wealthRefreshIdentityKey(symbol: blueprint.symbol, market: blueprint.market)
    }

    func persistResearchState() {
        if let data = try? JSONEncoder().encode(Array(researchSnapshotsByKey.values)) {
            Self.persistResearchSnapshotData(data)
            defaults.removeObject(forKey: StorageKey.researchSnapshots)
        }

        let statePayload = sourceStatesByKind.reduce(into: [String: String]()) { partialResult, entry in
            partialResult[entry.key.rawValue] = entry.value.rawValue
        }
        defaults.set(statePayload, forKey: StorageKey.sourceStates)
        defaults.set(sourceUpdatedAtByKind.mapKeys { $0.rawValue }, forKey: StorageKey.sourceUpdatedAt)
        defaults.set(sourceDetailByKind.mapKeys { $0.rawValue }, forKey: StorageKey.sourceDetails)
        defaults.set(lastResearchRefreshAt, forKey: StorageKey.lastResearchRefreshAt)
    }

    func applyResearchRefreshState(
        snapshots: [String: WealthExternalResearchSnapshot],
        states: [WealthExternalResearchKind: WealthExternalSignalState],
        updatedAt: [WealthExternalResearchKind: Date],
        details: [WealthExternalResearchKind: String],
        refreshedAt: Date
    ) {
        researchSnapshotsByKey = snapshots
        sourceStatesByKind = states
        sourceUpdatedAtByKind = updatedAt
        sourceDetailByKind = details
        lastResearchRefreshAt = refreshedAt
    }

    private static func loadResearchSnapshots(from defaults: UserDefaults) -> [String: WealthExternalResearchSnapshot] {
        let data: Data? = {
            if let fileURL = researchSnapshotFileURL(),
               let fileData = try? Data(contentsOf: fileURL) {
                return fileData
            }
            guard let stored = defaults.data(forKey: StorageKey.researchSnapshots) else { return nil }
            persistResearchSnapshotData(stored)
            defaults.removeObject(forKey: StorageKey.researchSnapshots)
            return stored
        }()

        guard let data,
              let snapshots = try? JSONDecoder().decode([WealthExternalResearchSnapshot].self, from: data) else {
            return [:]
        }
        return snapshots.reduce(into: [String: WealthExternalResearchSnapshot]()) { partialResult, snapshot in
            partialResult[snapshot.key] = snapshot
        }
    }

    private static func persistResearchSnapshotData(_ data: Data) {
        guard let fileURL = researchSnapshotFileURL(createIfNeeded: true) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func researchSnapshotFileURL(createIfNeeded: Bool = false) -> URL? {
        guard let baseURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: createIfNeeded
        ) else {
            return nil
        }

        return baseURL
            .appendingPathComponent("WealthCreationCache", isDirectory: true)
            .appendingPathComponent(CacheConstants.researchSnapshotFileName)
    }

    private static func invalidatePersistedResearchStateIfNeeded(defaults: UserDefaults) {
        let storedVersion = defaults.object(forKey: StorageKey.persistedResearchStateVersion) as? Int ?? 0
        guard storedVersion != CacheConstants.persistedResearchStateVersion else { return }

        defaults.removeObject(forKey: StorageKey.researchSnapshots)
        defaults.removeObject(forKey: StorageKey.sourceStates)
        defaults.removeObject(forKey: StorageKey.sourceUpdatedAt)
        defaults.removeObject(forKey: StorageKey.sourceDetails)
        defaults.removeObject(forKey: StorageKey.lastResearchRefreshAt)
        if let fileURL = researchSnapshotFileURL() {
            try? FileManager.default.removeItem(at: fileURL)
        }
        defaults.set(CacheConstants.persistedResearchStateVersion, forKey: StorageKey.persistedResearchStateVersion)
    }

    private static func sanitizeProviderEndpointsIfNeeded(defaults: UserDefaults) {
        for kind in WealthExternalResearchKind.allCases {
            guard let endpointString = normalizedEndpointString(defaults.string(forKey: kind.endpointStorageKey)) else {
                defaults.removeObject(forKey: kind.endpointStorageKey)
                continue
            }

            guard endpointString != CacheConstants.legacyMockProviderEndpoint else {
                defaults.removeObject(forKey: kind.endpointStorageKey)
                continue
            }

            defaults.set(endpointString, forKey: kind.endpointStorageKey)
        }
    }

    private static func normalizedEndpointString(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              URL(string: trimmed) != nil else {
            return nil
        }
        return trimmed
    }

    private static func loadConfiguredEndpoints(from defaults: UserDefaults) -> [WealthExternalResearchKind: URL] {
        WealthExternalResearchKind.allCases.reduce(into: [:]) { partial, kind in
            guard let endpointString = normalizedEndpointString(defaults.string(forKey: kind.endpointStorageKey)),
                  endpointString != CacheConstants.legacyMockProviderEndpoint,
                  let endpointURL = URL(string: endpointString) else { return }
            partial[kind] = endpointURL
        }
    }

    private static func loadProviderModes(from defaults: UserDefaults) -> [WealthExternalResearchKind: WealthExternalProviderMode] {
        WealthExternalResearchKind.allCases.reduce(into: [:]) { partial, kind in
            guard let raw = defaults.string(forKey: kind.modeStorageKey),
                  let mode = WealthExternalProviderMode(rawValue: raw) else {
                partial[kind] = .liveEndpoint
                return
            }
            partial[kind] = mode
        }
    }

    private static func loadSourceStates(from defaults: UserDefaults) -> [WealthExternalResearchKind: WealthExternalSignalState] {
        guard let stored = defaults.dictionary(forKey: StorageKey.sourceStates) as? [String: String] else {
            return [:]
        }
        return stored.reduce(into: [:]) { partial, item in
            guard let kind = WealthExternalResearchKind(rawValue: item.key),
                  let state = WealthExternalSignalState(rawValue: item.value) else { return }
            partial[kind] = state
        }
    }

    private static func loadSourceDates(from defaults: UserDefaults) -> [WealthExternalResearchKind: Date] {
        guard let stored = defaults.dictionary(forKey: StorageKey.sourceUpdatedAt) as? [String: Date] else {
            return [:]
        }
        return stored.reduce(into: [:]) { partial, item in
            guard let kind = WealthExternalResearchKind(rawValue: item.key) else { return }
            partial[kind] = item.value
        }
    }

    private static func loadSourceDetails(from defaults: UserDefaults) -> [WealthExternalResearchKind: String] {
        guard let stored = defaults.dictionary(forKey: StorageKey.sourceDetails) as? [String: String] else {
            return [:]
        }
        return stored.reduce(into: [:]) { partial, item in
            guard let kind = WealthExternalResearchKind(rawValue: item.key) else { return }
            partial[kind] = item.value
        }
    }
}

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        reduce(into: [:]) { partial, item in
            partial[transform(item.key)] = item.value
        }
    }
}
