import SwiftUI

enum WealthAggressionMode: String {
    case moderate = "MODERATE"
    case aggressive = "AGGRESSIVE"
    case protect = "LOCK-IN"

    var color: Color {
        switch self {
        case .moderate: return WealthTheme.blue
        case .aggressive: return WealthTheme.orange
        case .protect: return WealthTheme.green
        }
    }
}

enum WealthHungerMode: String {
    case hunt = "HUNT"
    case press = "PRESS"
    case stalk = "STALK"
    case protect = "PROTECT"

    var color: Color {
        switch self {
        case .hunt: return WealthTheme.red
        case .press: return WealthTheme.orange
        case .stalk: return WealthTheme.cyan
        case .protect: return WealthTheme.green
        }
    }
}

enum WealthExecutionStyle: String {
    case strike = "STRIKE"
    case staged = "STAGED"
    case stealth = "STEALTH"
    case wait = "WAIT"

    var color: Color {
        switch self {
        case .strike: return WealthTheme.green
        case .staged: return WealthTheme.orange
        case .stealth: return WealthTheme.purple
        case .wait: return WealthTheme.blue
        }
    }
}

enum WealthTrustState: String {
    case verified = "VERIFIED"
    case usable = "USABLE"
    case caution = "CAUTION"
    case weak = "WEAK"

    var color: Color {
        switch self {
        case .verified: return WealthTheme.green
        case .usable: return WealthTheme.purple
        case .caution: return WealthTheme.gold
        case .weak: return WealthTheme.red
        }
    }
}

enum WealthMarketRegime: String {
    case riskOn = "RISK-ON"
    case balanced = "BALANCED"
    case defensive = "DEFENSIVE"

    var color: Color {
        switch self {
        case .riskOn: return WealthTheme.green
        case .balanced: return WealthTheme.blue
        case .defensive: return WealthTheme.gold
        }
    }
}
