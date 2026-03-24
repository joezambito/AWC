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
        activatableTitles.count
    }

    var activationCoverage: Double {
        guard totalActivatableCount > 0 else { return 0 }
        return Double(enabledTitles.count) / Double(totalActivatableCount)
    }

    func enableAllAvailable() {
        enabledTitles = activatableTitles
        persist()
    }

    func enableAllForCurrentMode() {
        enabledTitles = runnableTitlesForCurrentMode()
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
        enabledTitles.intersection(runnableTitlesForCurrentMode()).count
    }

    var totalRunnableCount: Int {
        runnableTitlesForCurrentMode().count
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

    private func persist() {
        defaults.set(Array(enabledTitles).sorted(), forKey: key)
    }
}
