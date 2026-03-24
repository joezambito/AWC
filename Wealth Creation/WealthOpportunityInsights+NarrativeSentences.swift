import Foundation

extension Opportunity {
    var topDriversSentence: String {
        let drivers = intelligenceDrivers
            .map { trimmed($0) }
            .filter { !$0.isEmpty }
            .prefix(2)
        let channels = intelligenceChannels
            .map { trimmed($0) }
            .filter { !$0.isEmpty }
            .prefix(2)

        let driverText = drivers.joined(separator: " and ")
        let channelText = channels.joined(separator: " and ")

        if !driverText.isEmpty && !channelText.isEmpty {
            return "Top drivers are \(driverText.lowercased()) through \(channelText.lowercased())."
        }
        if !driverText.isEmpty {
            return "Top drivers are \(driverText.lowercased())."
        }
        if !channelText.isEmpty {
            return "AI is leaning on \(channelText.lowercased())."
        }
        return ""
    }

    var flowSentence: String {
        var flow: [String] = []

        if optionsFlowStrength >= 60 {
            flow.append("options flow is \(optionsFlowLabel.lowercased())")
        }
        if darkPoolStrength >= 60 {
            flow.append("dark pool flow is \(darkPoolLabel.lowercased())")
        }
        if insiderStrength >= 50 {
            flow.append("insider read is \(insiderLabel.lowercased())")
        }
        if filingStrength >= 50 {
            flow.append("13F support is \(filingLabel.lowercased())")
        }

        guard !flow.isEmpty else { return "" }
        return "Supporting flow says " + flow.joined(separator: ", ") + "."
    }

    var activeSignalSentence: String {
        let phrases = activeSignalPhrases.prefix(3).map { $0.lowercased() }
        guard !phrases.isEmpty else { return "" }
        return "Signal stack reads " + phrases.joined(separator: ", ") + "."
    }

    var profitEdgeSentence: String {
        guard trueCost > 0 else { return "" }

        if isGreenBuyReady {
            return "Projected net profit is \(WealthFormat.money(expectedNetProfit)) after costs on \(WealthFormat.money(trueCost)) deployed."
        }
        if clearsProfitGuard {
            return "Net edge is still positive at \(WealthFormat.money(expectedNetProfit)), but another gate is holding the order back."
        }
        return "Current projected net profit is \(WealthFormat.money(expectedNetProfit)), so AI is not treating it as buy-ready yet."
    }
}
