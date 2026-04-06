import Foundation
import SwiftUI

enum WealthBrainModuleClassification: String {
    case intelSupport = "INTEL SUPPORT"
    case controlRule = "CONTROL RULE"
    case executionSafety = "EXECUTION SAFETY"
    case displayOnly = "DISPLAY ONLY"
    case unusedNotInstalled = "UNUSED / NOT INSTALLED"

    var tint: Color {
        switch self {
        case .intelSupport:
            return WealthTheme.green
        case .controlRule:
            return WealthTheme.orange
        case .executionSafety:
            return WealthTheme.red
        case .displayOnly:
            return WealthTheme.cyan
        case .unusedNotInstalled:
            return WealthTheme.grey
        }
    }
}

enum WealthBrainModuleActivityState: String {
    case on = "ON"
    case off = "OFF"
    case live = "LIVE"
    case fallback = "FALLBACK"
    case standby = "STANDBY"
    case notInstalled = "NOT INSTALLED"

    var tint: Color {
        switch self {
        case .on, .live:
            return WealthTheme.green
        case .fallback:
            return WealthTheme.yellow
        case .standby:
            return WealthTheme.cyan
        case .off, .notInstalled:
            return WealthTheme.grey
        }
    }
}

struct WealthBrainModuleTruth: Hashable {
    let title: String
    let classification: WealthBrainModuleClassification
    let activityState: WealthBrainModuleActivityState
    let allowsToggle: Bool
    let detail: String
}

@MainActor
enum WealthBrainModuleRegistry {
    private static let executionSafetyTitles: Set<String> = [
        "Liquidity / Slippage Controls",
        "Execution Safety Layer",
        "Tail-Risk Overrides"
    ]

    private static let controlRuleTitles: Set<String> = [
        "Correlation / Concentration Controls",
        "Portfolio Heat Map",
        "Exposure Balancer",
        "Rollback / Safe Revert"
    ]

    private static let displayOnlyTitles: Set<String> = []

    private static let unusedTitles: Set<String> = [
        "TIKR",
        "Trade Ideas (HollyAI)",
        "Nansen",
        "Alternative Data Providers"
    ]

    private static let providerAliases: [String: String] = [
        "Dark Pool": "Dark Pool Data",
        "Insider": "Insider Monitoring",
        "13F": "13F Filing Analysis",
        "Earnings": "Event Calendar Engine",
        "Macro": "Event Calendar Engine"
    ]

    static let providerTrainingTitles: [String] = [
        "Outcome",
        "Backtest",
        "Retraining",
        "Research Mesh"
    ]

    static func truth(for item: WealthAIStackItem) -> WealthBrainModuleTruth {
        truth(forTitle: item.title)
    }

    static func truth(forTitle rawTitle: String) -> WealthBrainModuleTruth {
        let title = canonicalTitle(for: rawTitle)
        let classification = classification(for: title)
        let activityState = activityState(for: title, classification: classification)
        let allowsToggle = classification != .unusedNotInstalled && classification != .displayOnly

        return WealthBrainModuleTruth(
            title: title,
            classification: classification,
            activityState: activityState,
            allowsToggle: allowsToggle,
            detail: detail(for: title, classification: classification, activityState: activityState)
        )
    }

    static func canonicalTitle(for rawTitle: String) -> String {
        providerAliases[rawTitle] ?? rawTitle
    }

    static func isEnabled(title rawTitle: String) -> Bool {
        let title = canonicalTitle(for: rawTitle)
        let providerStore = WealthExternalDataStore.shared

        switch title {
        case "Options Flow":
            return providerStore.optionsFlowEnabled
        case "Dark Pool Data":
            return providerStore.darkPoolEnabled
        case "Insider Monitoring":
            return providerStore.insiderEnabled
        case "13F Filing Analysis":
            return providerStore.filing13FEnabled
        case "Event Calendar Engine":
            return providerStore.earningsCalendarEnabled || providerStore.macroCalendarEnabled
        case "Outcome":
            return providerStore.liveOutcomeLearningEnabled
        case "Backtest":
            return providerStore.backtestEngineEnabled
        case "Retraining":
            return providerStore.retrainingEnabled
        case "Research Mesh":
            return providerStore.researchMeshEnabled
        default:
            return WealthBrainToggleStore.shared.isEnabled(title: title)
        }
    }

    static func setEnabled(_ enabled: Bool, title rawTitle: String) {
        let title = canonicalTitle(for: rawTitle)
        let providerStore = WealthExternalDataStore.shared

        switch title {
        case "Options Flow":
            providerStore.setEnabled(enabled, for: .optionsFlow)
        case "Dark Pool Data":
            providerStore.setEnabled(enabled, for: .darkPool)
        case "Insider Monitoring":
            providerStore.setEnabled(enabled, for: .insider)
        case "13F Filing Analysis":
            providerStore.setEnabled(enabled, for: .filing13F)
        case "Event Calendar Engine":
            providerStore.setEnabled(enabled, for: .earningsCalendar)
            providerStore.setEnabled(enabled, for: .macroCalendar)
        case "Outcome":
            providerStore.liveOutcomeLearningEnabled = enabled
            providerStore.persist()
        case "Backtest":
            providerStore.backtestEngineEnabled = enabled
            providerStore.persist()
        case "Retraining":
            providerStore.retrainingEnabled = enabled
            providerStore.persist()
        case "Research Mesh":
            providerStore.researchMeshEnabled = enabled
            providerStore.persist()
        default:
            let store = WealthBrainToggleStore.shared
            let item = WealthAIStackItem(title: title, note: "", status: .foundation)
            let currentlyEnabled = store.isEnabled(title: title)
            guard currentlyEnabled != enabled else { return }
            store.toggle(item)
        }
    }

    static func binding(forTitle title: String) -> Binding<Bool> {
        Binding(
            get: { isEnabled(title: title) },
            set: { setEnabled($0, title: title) }
        )
    }

    static func classification(for rawTitle: String) -> WealthBrainModuleClassification {
        let title = canonicalTitle(for: rawTitle)

        if unusedTitles.contains(title) {
            return .unusedNotInstalled
        }
        if executionSafetyTitles.contains(title) {
            return .executionSafety
        }
        if controlRuleTitles.contains(title) {
            return .controlRule
        }
        if displayOnlyTitles.contains(title) {
            return .displayOnly
        }
        return .intelSupport
    }

    private static func activityState(
        for title: String,
        classification: WealthBrainModuleClassification
    ) -> WealthBrainModuleActivityState {
        guard classification != .unusedNotInstalled else { return .notInstalled }
        guard isEnabled(title: title) else { return .off }

        switch title {
        case "Options Flow":
            return providerActivityState(for: .optionsFlow)
        case "Dark Pool Data":
            return providerActivityState(for: .darkPool)
        case "Insider Monitoring":
            return providerActivityState(for: .insider)
        case "13F Filing Analysis":
            return providerActivityState(for: .filing13F)
        case "Event Calendar Engine":
            let earnings = providerActivityState(for: .earningsCalendar)
            let macro = providerActivityState(for: .macroCalendar)
            return (earnings == .live || macro == .live) ? .live : .fallback
        case "Phone Staged Compute":
#if targetEnvironment(macCatalyst)
            return .standby
#else
            return .on
#endif
        case "Mac Full Compute":
#if targetEnvironment(macCatalyst)
            return .on
#else
            return .standby
#endif
        default:
            return .on
        }
    }

    private static func providerActivityState(for kind: WealthExternalResearchKind) -> WealthBrainModuleActivityState {
        let providerStore = WealthExternalDataStore.shared
        guard providerStore.isEnabled(kind) else { return .off }

        let state = providerStore.sourceStatesByKind[kind] ?? .syntheticFallback
        switch state {
        case .freshOnline, .cached:
            return .live
        case .syntheticFallback:
            return .fallback
        case .unavailable:
            return .fallback
        case .off:
            return .off
        }
    }

    private static func detail(
        for title: String,
        classification: WealthBrainModuleClassification,
        activityState: WealthBrainModuleActivityState
    ) -> String {
        switch classification {
        case .intelSupport:
            switch title {
            case "Trend Detection":
                return "Explicit trend evidence now feeds the AI support path."
            case "Ranking Management":
                return "Rank support now breaks deep ties with live quality, trust, and anomaly context."
            case "Risk Management System":
                return "Risk intelligence now informs evaluation without replacing protected hard safety rules."
            default:
                return activityState == .fallback
                    ? "Installed and contributing through fallback or synthetic support."
                    : "Installed and contributing through the live AI support path."
            }
        case .controlRule:
            return "Installed control layer. It remains separate from raw intelligence inputs."
        case .executionSafety:
            return "Installed safety layer. It protects execution without pretending to be a raw intel signal."
        case .displayOnly:
            return "Display-only operator row."
        case .unusedNotInstalled:
            return "Not installed into the live backend."
        }
    }
}
