import SwiftUI

enum MarketSessionState: String {
    case tradableNow = "READY NOW"
    case afterHours = "AFTER HOURS"
    case waitingForOpen = "WAITING OPEN"
    case recheckAtOpen = "RECHECK OPEN"

    var color: Color {
        switch self {
        case .tradableNow: return WealthTheme.cyan
        case .afterHours: return WealthTheme.blue
        case .waitingForOpen: return WealthTheme.purple
        case .recheckAtOpen: return WealthTheme.gold
        }
    }

    var canTradeNow: Bool {
        self == .tradableNow
    }
}

enum BrokerSessionClock {
    static func state(for market: String, brokerName: String, date: Date = .now) -> MarketSessionState {
        let canonicalMarket = WealthMarketCalendar.canonicalMarket(for: market)
        let normalizedBroker = brokerName.uppercased()
        let baseState = MarketSessionClock.state(for: canonicalMarket, date: date)

        if supportsTwentyFourHourTrading(brokerName: normalizedBroker, market: canonicalMarket) {
            return baseState == .recheckAtOpen ? .recheckAtOpen : .tradableNow
        }

        if baseState == .afterHours && supportsExtendedHours(brokerName: normalizedBroker, market: canonicalMarket) {
            return .tradableNow
        }

        return baseState
    }

    static func nextTradingText(for market: String, brokerName: String, date: Date = .now) -> String {
        let normalizedBroker = brokerName.uppercased()
        let canonicalMarket = WealthMarketCalendar.canonicalMarket(for: market)
        let currentState = state(for: canonicalMarket, brokerName: normalizedBroker, date: date)

        if currentState.canTradeNow { return "Trading now" }
        if supportsTwentyFourHourTrading(brokerName: normalizedBroker, market: canonicalMarket) { return "Trading now" }

        guard let nextDate = nextTradingDate(for: canonicalMarket, brokerName: normalizedBroker, date: date) else {
            return currentState.rawValue
        }

        return WealthFormat.dayClock(nextDate)
    }

    static func nextTradingDate(for market: String, brokerName: String, date: Date = .now) -> Date? {
        let normalizedBroker = brokerName.uppercased()
        let canonicalMarket = WealthMarketCalendar.canonicalMarket(for: market)
        let includeAfterHours = supportsExtendedHours(brokerName: normalizedBroker, market: canonicalMarket)
        return MarketSessionClock.nextTradingDate(for: canonicalMarket, date: date, includeAfterHours: includeAfterHours)
    }

    private static func supportsTwentyFourHourTrading(brokerName: String, market: String) -> Bool {
        if market.contains("CRYPTO") { return true }
        if market == "FX" { return ["IBKR", "CMC", "SAXO"].contains(where: brokerName.contains) }
        if ["CME", "CBOT", "NYMEX", "COMEX", "ICE"].contains(market), brokerName.contains("IBKR") {
            return true
        }
        return false
    }

    private static func supportsExtendedHours(brokerName: String, market: String) -> Bool {
        if market.contains("CRYPTO") || market == "FX" { return true }

        guard brokerName.contains("IBKR") else { return false }

        return ["NASDAQ", "NYSE", "AMEX", "ETF", "REIT", "ADR", "OTC", "TSX", "TSXV", "CSE"].contains(market)
    }
}

enum MarketSessionClock {
    static func state(for market: String, date: Date = .now) -> MarketSessionState {
        WealthMarketCalendar.state(for: market, date: date)
    }

    static func nextTradingDate(for market: String, date: Date = .now) -> Date? {
        WealthMarketCalendar.nextTradingDate(for: market, date: date)
    }

    static func nextTradingDate(for market: String, date: Date = .now, includeAfterHours: Bool) -> Date? {
        WealthMarketCalendar.nextTradingDate(for: market, date: date, includeAfterHours: includeAfterHours)
    }
}

enum WealthScoreMap {
    static func style(for score: Int, rank: Int? = nil) -> ScoreStyle {
        switch score {
        case 1...20:
            return ScoreStyle(tier: .strong, state: .buy, color: WealthTheme.green)
        case 21...39:
            return ScoreStyle(tier: .moderate, state: .monitor, color: WealthTheme.blue)
        case 40...59:
            return ScoreStyle(tier: .watch, state: .watchActive, color: WealthTheme.orange)
        default:
            return ScoreStyle(tier: .weak, state: .weak, color: WealthTheme.red)
        }
    }
}
