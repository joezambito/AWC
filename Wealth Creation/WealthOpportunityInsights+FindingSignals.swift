import Foundation

extension Opportunity {
    var uniqueFindings: [String] {
        var reasons: [String] = []

        if let recoverySetupLabel {
            reasons.append(recoverySetupLabel)
        }
        if !trimmed(sourceTrigger).isEmpty {
            reasons.append(trimmed(sourceTrigger).uppercased())
        }
        if let topDriver = intelligenceDrivers.first, !trimmed(topDriver).isEmpty {
            reasons.append(trimmed(topDriver).uppercased())
        }
        if let topChannel = intelligenceChannels.first, !trimmed(topChannel).isEmpty {
            reasons.append(trimmed(topChannel).uppercased())
        }
        if optionsFlowStrength >= 60 {
            reasons.append("OPTIONS FLOW STRONG")
        }
        if darkPoolStrength >= 60 {
            reasons.append("DARK POOL STRONG")
        }
        if insiderStrength >= 50 {
            reasons.append("INSIDER SUPPORT")
        }
        if filingStrength >= 50 {
            reasons.append("13F SUPPORT")
        }
        reasons.append(contentsOf: activeSignalPhrases)

        return Array(NSOrderedSet(array: reasons)) as? [String] ?? reasons
    }

    var activeSignalPhrases: [String] {
        [
            advancedSignal.trendState,
            advancedSignal.patternState,
            advancedSignal.smartMoneyState,
            advancedSignal.eventState,
            advancedSignal.executionState
        ]
        .filter {
            !$0.contains("NEUTRAL") &&
            !$0.contains("LIGHT") &&
            !$0.contains("MIXED") &&
            !$0.contains("FLAT")
        }
    }

    func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
