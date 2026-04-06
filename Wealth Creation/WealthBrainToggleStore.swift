import Foundation
import Combine

enum WealthBrainRuntimeMode: String {
    case demo = "DEMO"
    case paper = "PAPER"
    case live = "LIVE"
}

@MainActor
final class WealthBrainToggleStore: ObservableObject {
    static let shared = WealthBrainToggleStore()

    @Published private(set) var enabledTitles: Set<String>

    private let defaults = UserDefaults.standard
    private let key = "awc_brain_enabled_titles_v1"

    private init() {
        let stored = defaults.array(forKey: key) as? [String] ?? []
        let catalogTitles = Self.makeActivatableTitles()
        enabledTitles = stored.isEmpty ? catalogTitles : Set(stored)
        synchronizeWithCatalog()
    }

    func isEnabled(_ item: WealthAIStackItem) -> Bool {
        enabledTitles.contains(item.title)
    }

    func isEnabled(title: String) -> Bool {
        enabledTitles.contains(title)
    }

    func toggle(_ item: WealthAIStackItem) {
        if enabledTitles.contains(item.title) {
            enabledTitles.remove(item.title)
        } else {
            enabledTitles.insert(item.title)
        }
        persist()
    }

    var totalActivatableCount: Int {
        runtimeTrackedTitles.count
    }

    var activationCoverage: Double {
        guard totalRunnableCount > 0 else { return 0 }
        return Double(activeRuntimeCount) / Double(totalRunnableCount)
    }

    func enableAllAvailable() {
        enabledTitles = activatableTitles
        setProviderTrainingModulesEnabled(true)
        persist()
    }

    func enableAllForCurrentMode() {
        enabledTitles = runnableTitlesForCurrentMode()
        setProviderTrainingModulesEnabled(true)
        persist()
    }

    var runtimeMode: WealthBrainRuntimeMode {
        let protection = WealthProtectionSettingsStore.shared
        let broker = WealthBrokerStore.shared
        let sync = WealthSyncStore.shared

        if protection.demoMode {
            return .demo
        }
        if broker.paperTradingEnabled || !broker.liveTradingEnabled || !sync.liveMode {
            return .paper
        }
        return .live
    }

    func runnableTitlesForCurrentMode() -> Set<String> {
        switch runtimeMode {
        case .demo, .paper, .live:
            return activatableTitles
        }
    }

    var activeRuntimeCount: Int {
        runtimeTrackedTitles.filter { WealthBrainModuleRegistry.isEnabled(title: $0) }.count
    }

    var totalRunnableCount: Int {
        runtimeTrackedTitles.count
    }

    var runtimeCoverageText: String {
        "\(activeRuntimeCount)/\(max(totalRunnableCount, 1)) \(runtimeMode.rawValue)"
    }

    private var defaultEnabledTitles: Set<String> {
        runnableTitlesForCurrentMode()
    }

    private var activatableTitles: Set<String> {
        Self.makeActivatableTitles()
    }

    private var runtimeTrackedTitles: Set<String> {
        activatableTitles.union(Self.providerTrainingTitles)
    }

    private static let providerTrainingTitles = Set(WealthBrainModuleRegistry.providerTrainingTitles)

    private static func makeActivatableTitles() -> Set<String> {
        Set(
            WealthAIStackCatalog.groups
                .flatMap(\.items)
                .filter { $0.status != .external }
                .map(\.title)
        )
    }

    private func synchronizeWithCatalog() {
        let runnable = runnableTitlesForCurrentMode()
        enabledTitles = enabledTitles
            .intersection(activatableTitles)
            .intersection(runnable)
            .union(defaultEnabledTitles.subtracting(enabledTitles))
        persist()
    }

    private func setProviderTrainingModulesEnabled(_ enabled: Bool) {
        for title in Self.providerTrainingTitles {
            WealthBrainModuleRegistry.setEnabled(enabled, title: title)
        }
    }

    private func persist() {
        defaults.set(Array(enabledTitles).sorted(), forKey: key)
    }
}
