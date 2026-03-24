import SwiftUI

enum ScoreTier: String {
    case strong = "STRONG"
    case moderate = "MODERATE"
    case watch = "WATCH"
    case weak = "WEAK"

    var color: Color {
        switch self {
        case .strong: return WealthTheme.green
        case .moderate: return WealthTheme.purple
        case .watch: return WealthTheme.gold
        case .weak: return WealthTheme.red
        }
    }
}

enum OpportunityState: String {
    case buy = "BUY"
    case watchActive = "WATCH ACTIVE"
    case monitor = "MONITOR"
    case weak = "WEAK"
}

struct ScoreStyle {
    let tier: ScoreTier
    let state: OpportunityState
    let color: Color
}

enum WealthDecisionBias: String {
    case buy = "BUY"
    case hold = "HOLD"
    case avoid = "AVOID"

    var color: Color {
        switch self {
        case .buy: return WealthTheme.green
        case .hold: return WealthTheme.blue
        case .avoid: return WealthTheme.red
        }
    }
}

enum WealthPermissionState: String {
    case go = "GO"
    case wait = "WAIT"
    case blocked = "BLOCKED"

    var color: Color {
        switch self {
        case .go: return WealthTheme.green
        case .wait: return WealthTheme.blue
        case .blocked: return WealthTheme.red
        }
    }
}

enum WealthConvictionLevel: String {
    case top = "TOP"
    case strong = "STRONG"
    case watch = "WATCH"
    case weak = "WEAK"

    var color: Color {
        switch self {
        case .top: return WealthTheme.green
        case .strong: return WealthTheme.cyan
        case .watch: return WealthTheme.gold
        case .weak: return WealthTheme.red
        }
    }
}

enum WealthRotationBias: String {
    case add = "ADD"
    case keep = "KEEP"
    case rotate = "ROTATE"
    case block = "BLOCK"

    var color: Color {
        switch self {
        case .add: return WealthTheme.green
        case .keep: return WealthTheme.cyan
        case .rotate: return WealthTheme.orange
        case .block: return WealthTheme.red
        }
    }
}
