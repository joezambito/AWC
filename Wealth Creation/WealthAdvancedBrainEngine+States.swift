import Foundation

extension WealthAdvancedBrainEngine {
    static func trendState(for score: Int) -> String {
        switch score {
        case 8...: return "TRENDING STRONG"
        case 4...: return "TREND EARLY"
        case ...(-3): return "TREND WEAK"
        default: return "TREND NEUTRAL"
        }
    }

    static func momentumState(for score: Int) -> String {
        switch score {
        case 7...: return "MOMENTUM STRONG"
        case 3...: return "MOMENTUM BUILDING"
        case ...(-3): return "MOMENTUM WEAK"
        default: return "MOMENTUM FLAT"
        }
    }

    static func patternState(for score: Int) -> String {
        switch score {
        case 6...: return "PATTERN BULLISH"
        case 3...: return "PATTERN STRONG"
        case ...(-3): return "PATTERN WEAK"
        default: return "PATTERN NEUTRAL"
        }
    }

    static func smartMoneyState(for score: Int) -> String {
        switch score {
        case 9...: return "SMART MONEY STRONG"
        case 5...: return "SMART MONEY ACTIVE"
        case ...(-1): return "SMART MONEY FADE"
        default: return "SMART MONEY LIGHT"
        }
    }

    static func eventState(for score: Int) -> String {
        switch score {
        case 6...: return "EVENT STRONG"
        case 2...: return "EVENT SUPPORT"
        case ...(-2): return "EVENT RISK"
        default: return "EVENT NEUTRAL"
        }
    }

    static func executionState(for score: Int) -> String {
        switch score {
        case 5...: return "EXECUTION CLEAN"
        case 2...: return "EXECUTION READY"
        case ...(-2): return "EXECUTION RISK"
        default: return "EXECUTION WATCH"
        }
    }

    static func portfolioState(for score: Int) -> String {
        switch score {
        case 4...: return "PORTFOLIO FIT STRONG"
        case 1...: return "PORTFOLIO FIT"
        case ...(-2): return "PORTFOLIO CROWDING"
        default: return "PORTFOLIO NEUTRAL"
        }
    }

    static func anomalyState(for score: Int) -> String {
        switch score {
        case 8...: return "ANOMALY HIGH"
        case 4...: return "ANOMALY WATCH"
        default: return "STABLE"
        }
    }
}
