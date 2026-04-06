import Foundation
import SwiftUI

struct WealthProviderBias: Hashable {
    let qualityLift: Double
    let confidenceLift: Double
    let rewardLift: Double
    let riskPenalty: Double

    static let neutral = WealthProviderBias(qualityLift: 0, confidenceLift: 0, rewardLift: 0, riskPenalty: 0)
}

enum WealthExternalProviderMode: String, CaseIterable, Codable, Hashable, Identifiable {
    case liveEndpoint = "LIVE_ENDPOINT"
    case mockTest = "MOCK_TEST"
    case syntheticFallback = "SYNTHETIC_FALLBACK"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .liveEndpoint:
            return "Live Endpoint"
        case .mockTest:
            return "Mock/Test"
        case .syntheticFallback:
            return "Synthetic Fallback"
        }
    }
}

enum WealthExternalResearchKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case optionsFlow
    case darkPool
    case insider
    case filing13F
    case earningsCalendar
    case macroCalendar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .optionsFlow: return "Options Flow"
        case .darkPool: return "Dark Pool"
        case .insider: return "Insider"
        case .filing13F: return "13F"
        case .earningsCalendar: return "Earnings"
        case .macroCalendar: return "Macro"
        }
    }

    var detail: String {
        switch self {
        case .optionsFlow: return "Tape and skew"
        case .darkPool: return "Accumulation prints"
        case .insider: return "Director behavior"
        case .filing13F: return "Institutional positioning"
        case .earningsCalendar: return "Calendar risk"
        case .macroCalendar: return "Rates and event risk"
        }
    }

    var endpointStorageKey: String {
        switch self {
        case .optionsFlow: return "awc_provider_options_flow_endpoint"
        case .darkPool: return "awc_provider_dark_pool_endpoint"
        case .insider: return "awc_provider_insider_endpoint"
        case .filing13F: return "awc_provider_13f_endpoint"
        case .earningsCalendar: return "awc_provider_earnings_endpoint"
        case .macroCalendar: return "awc_provider_macro_endpoint"
        }
    }

    var modeStorageKey: String {
        switch self {
        case .optionsFlow: return "awc_provider_options_flow_mode"
        case .darkPool: return "awc_provider_dark_pool_mode"
        case .insider: return "awc_provider_insider_mode"
        case .filing13F: return "awc_provider_13f_mode"
        case .earningsCalendar: return "awc_provider_earnings_mode"
        case .macroCalendar: return "awc_provider_macro_mode"
        }
    }

    var cacheTTL: TimeInterval {
        switch self {
        case .optionsFlow, .darkPool:
            return 30 * 60
        case .insider, .filing13F:
            return 6 * 60 * 60
        case .earningsCalendar, .macroCalendar:
            return 60 * 60
        }
    }
}

enum WealthExternalSignalState: String, Codable, Hashable {
    case freshOnline = "FRESH ONLINE"
    case cached = "CACHED"
    case syntheticFallback = "SYNTHETIC FALLBACK"
    case unavailable = "UNAVAILABLE"
    case off = "OFF"

    var tint: Color {
        switch self {
        case .freshOnline:
            return WealthTheme.green
        case .cached:
            return WealthTheme.cyan
        case .syntheticFallback:
            return WealthTheme.orange
        case .unavailable:
            return WealthTheme.silver
        case .off:
            return WealthTheme.grey
        }
    }
}

struct WealthExternalResearchValue: Codable, Hashable {
    let kind: WealthExternalResearchKind
    let value: Double
    let state: WealthExternalSignalState
    let updatedAt: Date?
    let detail: String
}

struct WealthExternalResearchSnapshot: Codable, Hashable {
    let key: String
    let symbol: String
    let market: String
    let sources: [WealthExternalResearchValue]
    let lastUpdatedAt: Date

    func source(for kind: WealthExternalResearchKind) -> WealthExternalResearchValue? {
        sources.first { $0.kind == kind }
    }
}

struct WealthProviderSource: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let status: String
    let detail: String
    let tint: Color
}
