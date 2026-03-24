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

    private enum StorageKey {
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
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
    }

    func normalizedSignal(for blueprint: OpportunityBlueprint) -> WealthNormalizedExternalSignal {
        activeFeedClients().reduce(WealthNormalizedExternalSignal.zero) { partial, client in
            partial.merged(with: client.signal(for: blueprint))
        }
    }

    private func activeFeedClients() -> [any WealthExternalFeedClient] {
        var clients: [any WealthExternalFeedClient] = []
        if optionsFlowEnabled { clients.append(WealthOptionsFlowFeedClient()) }
        if darkPoolEnabled { clients.append(WealthDarkPoolFeedClient()) }
        if insiderEnabled { clients.append(WealthInsiderFeedClient()) }
        if filing13FEnabled { clients.append(WealthFiling13FFeedClient()) }
        if earningsCalendarEnabled { clients.append(WealthEarningsFeedClient()) }
        if macroCalendarEnabled { clients.append(WealthMacroFeedClient()) }
        return clients
    }
}
