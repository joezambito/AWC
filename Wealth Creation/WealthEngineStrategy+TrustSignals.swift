import SwiftUI

extension WealthEngineStore {
    static func sourceReliabilityScore(for blueprint: OpportunityBlueprint) -> Int {
        var score = 35

        if blueprint.dataOrigin.localizedCaseInsensitiveContains("Price/Volume Feed") { score += 18 }
        if blueprint.dataOrigin.localizedCaseInsensitiveContains("Structured Scan") { score += 14 }
        if blueprint.dataOrigin.localizedCaseInsensitiveContains("Smart Money") { score += 16 }
        if blueprint.dataOrigin.localizedCaseInsensitiveContains("Macro Scan") { score += 10 }
        if blueprint.dataOrigin.localizedCaseInsensitiveContains("Public News") { score += 8 }
        if blueprint.dataOrigin.localizedCaseInsensitiveContains("Social Feed") { score += 2 }
        if blueprint.dataOrigin.localizedCaseInsensitiveContains("Thin Feed") { score -= 28 }

        switch blueprint.dataQualityLabel {
        case "FRESH": score += 14
        case "AGING": score -= 6
        case "STALE": score -= 22
        default: break
        }

        return min(100, max(5, score))
    }

    static func shareReliabilityScore(
        for blueprint: OpportunityBlueprint,
        confidence: Int,
        safety: Int
    ) -> Int {
        var score = Int(round((blueprint.fundamental * 0.20) + (blueprint.technical * 0.18) + (blueprint.institutional * 0.16) + (blueprint.catalyst * 0.14) + (blueprint.sectorFlow * 0.10)))
        score += Int(round(Double(confidence) * 0.15))
        score += Int(round(Double(safety) * 0.12))
        score -= Int(round(blueprint.risk * 0.35))

        if blueprint.timeWindow == "UNKNOWN" { score -= 12 }
        if blueprint.urgency == "IGNORE" { score -= 18 }

        return min(100, max(5, score))
    }

    static func trustState(sourceReliability: Int, shareReliability: Int) -> WealthTrustState {
        let combined = Int(round((Double(sourceReliability) * 0.55) + (Double(shareReliability) * 0.45)))
        switch combined {
        case 80...: return .verified
        case 65..<80: return .usable
        case 45..<65: return .caution
        default: return .weak
        }
    }

    static func trustReason(
        for blueprint: OpportunityBlueprint,
        sourceReliability: Int,
        shareReliability: Int,
        trustState: WealthTrustState,
        advanced: WealthAdvancedSignalProfile
    ) -> String {
        let governanceTail = WealthBrainToggleStore.shared.isEnabled(title: "Audit / Decision Trail")
            ? " Decision trail is being recorded."
            : ""
        switch trustState {
        case .verified:
            return "Trusted setup. Source reliability is \(sourceReliability) and share reliability is \(shareReliability), with \(advanced.smartMoneyState.lowercased()) and \(advanced.executionState.lowercased()).\(governanceTail)"
        case .usable:
            return "Usable setup. The information is good enough to act on, but the brain still wants confirmation before pushing full size because \(advanced.patternState.lowercased()) is not fully locked yet.\(governanceTail)"
        case .caution:
            return "Caution. The data or the share quality is only mid-tier, and \(advanced.anomalyState.lowercased()) is keeping the brain patient.\(governanceTail)"
        case .weak:
            return "\(blueprint.symbol) is not trusted enough yet. The data stack is too weak or stale for aggressive action, especially with \(advanced.eventState.lowercased()).\(governanceTail)"
        }
    }
}
