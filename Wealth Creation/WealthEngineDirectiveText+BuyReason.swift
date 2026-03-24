import Foundation

extension WealthEngineDirectiveText {
    static func buyReason(
        blueprint: OpportunityBlueprint,
        score: Int,
        confidence: Int,
        mode: WealthAggressionMode,
        goals: WealthGoalVector,
        advanced: WealthAdvancedSignalProfile
    ) -> String {
        let modeText: String
        switch mode {
        case .aggressive: modeText = "AI is leaning aggressively"
        case .moderate: modeText = "AI is leaning selectively"
        case .protect: modeText = "AI is leaning defensively"
        }

        let trigger = blueprint.sourceTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let driverText = blueprint.intelligenceDrivers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(2)
            .joined(separator: " and ")
        let channelText = blueprint.intelligenceChannels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(2)
            .joined(separator: " and ")

        var flowNotes: [String] = []
        if blueprint.optionsFlowStrength >= 60 { flowNotes.append("options flow is active") }
        if blueprint.darkPoolStrength >= 60 { flowNotes.append("dark pool buying is active") }
        if blueprint.insiderStrength >= 50 { flowNotes.append("insider support is active") }
        if blueprint.filingStrength >= 50 { flowNotes.append("13F support is active") }

        let moveText: String
        switch blueprint.priceChangePercent {
        case let move where move >= 2: moveText = "price is already pushing higher"
        case let move where move > 0: moveText = "price is edging higher"
        case let move where move <= -10: moveText = "price is heavily down and AI is reading it as a recovery setup"
        case let move where move < 0: moveText = "price is soft and AI wants the rebound to hold"
        default: moveText = "price is stable"
        }

        let signalStack = [advanced.trendState, advanced.patternState, advanced.smartMoneyState, advanced.eventState, advanced.executionState]
            .filter {
                !$0.contains("WEAK") &&
                !$0.contains("SOFT") &&
                !$0.contains("FLAT") &&
                !$0.contains("NEUTRAL") &&
                !$0.contains("LIGHT")
            }
            .prefix(3)
            .map { $0.lowercased() }
            .joined(separator: ", ")

        let dominant = goals.dominantTarget
        let goalGap = goals.progress(for: dominant).remaining
        let directive = WealthEngineStore.targetDirective(
            goals: goals,
            expectedNetProfit: max(12, (blueprint.probability * blueprint.price * (blueprint.timeWindow == "HOURS" ? 0.24 : (blueprint.timeWindow == "DAYS" ? 0.18 : 0.12))))
        ).lowercased()

        var sentences: [String] = []
        if !trigger.isEmpty {
            sentences.append("\(modeText) on \(blueprint.symbol) because \(trigger.lowercased()) is active.")
        } else {
            sentences.append("\(modeText) on \(blueprint.symbol) because the live setup is strengthening.")
        }
        if !driverText.isEmpty && !channelText.isEmpty {
            sentences.append("The main drivers are \(driverText.lowercased()) through \(channelText.lowercased()).")
        } else if !driverText.isEmpty {
            sentences.append("The main drivers are \(driverText.lowercased()).")
        } else if !channelText.isEmpty {
            sentences.append("The main channels are \(channelText.lowercased()).")
        }
        if !flowNotes.isEmpty {
            sentences.append("Flow check says \(flowNotes.joined(separator: ", ")).")
        }
        if !signalStack.isEmpty {
            sentences.append("Signal stack reads \(signalStack).")
        }
        if goalGap > 0 {
            sentences.append("\(dominant.capitalized) is still behind by \(WealthFormat.money(goalGap)), so campaign pressure remains active.")
        }
        sentences.append("Score is \(score), confidence is \(confidence)%, \(moveText), and the setup is tagged as \(blueprint.catalystBucket.lowercased()) with \(directive).")

        return sentences.joined(separator: " ")
    }
}
