import Foundation

extension Opportunity {
    var aiCommentary: String {
        let lead = trimmed(reviewSummary).isEmpty ? trimmed(sourceSummary) : trimmed(reviewSummary)
        let moveText = priceChangePercent >= 0
            ? "Price is up \(WealthFormat.percent(priceChangePercent))."
            : "Price is down \(WealthFormat.percent(priceChangePercent))."
        let structure = activeSignalPhrases.prefix(2).joined(separator: " and ").lowercased()
        let structureText = structure.isEmpty ? "" : " AI structure sees \(structure)."
        let driverText = topDriversSentence
        return [lead, driverText, moveText + structureText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var decisionMatrixText: String {
        [
            advancedSignal.trendState,
            advancedSignal.patternState,
            advancedSignal.smartMoneyState,
            advancedSignal.eventState,
            advancedSignal.executionState,
            advancedSignal.portfolioState
        ]
        .joined(separator: " · ")
    }

    var riskMatrixText: String {
        [
            "ANOMALY \(advancedSignal.anomalyState)",
            "TRUST \(trustState.rawValue)",
            "ENTRY \(permission.rawValue)",
            "ROTATION \(rotationBias.rawValue)"
        ]
        .joined(separator: " · ")
    }

    var aiFoundHeadline: String {
        let items = uniqueFindings
        if items.isEmpty {
            return trimmed(sourceTrigger).isEmpty ? symbol : trimmed(sourceTrigger)
        }
        return items.prefix(3).joined(separator: " · ")
    }

    var aiFoundDetail: String {
        var parts: [String] = []

        let trigger = trimmed(sourceTrigger)
        if !trigger.isEmpty {
            parts.append("AI found \(trigger.lowercased()).")
        }

        let driverText = topDriversSentence
        if !driverText.isEmpty {
            parts.append(driverText)
        }

        let flowText = flowSentence
        if !flowText.isEmpty {
            parts.append(flowText)
        }

        let structureText = activeSignalSentence
        if !structureText.isEmpty {
            parts.append(structureText)
        }

        let moneyText = profitEdgeSentence
        if !moneyText.isEmpty {
            parts.append(moneyText)
        }

        let review = trimmed(reviewSummary)
        if !review.isEmpty {
            parts.append(review)
        } else if !trimmed(sourceSummary).isEmpty {
            parts.append(trimmed(sourceSummary))
        }

        let unique = Array(NSOrderedSet(array: parts)) as? [String] ?? parts
        return unique.joined(separator: " ")
    }

    var whyPickedSummary: String {
        aiFoundHeadline
    }
}
