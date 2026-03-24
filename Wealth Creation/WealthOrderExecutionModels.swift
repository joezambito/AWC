import SwiftUI

enum OrderExecutionState: String, CaseIterable {
    case ready = "READY"
    case submitted = "SUBMITTED"
    case pending = "PENDING"
    case partial = "PARTIAL"
    case filled = "PURCHASED"

    var color: Color {
        switch self {
        case .ready: return WealthTheme.grey
        case .submitted: return WealthTheme.yellow
        case .pending: return WealthTheme.yellow
        case .partial: return WealthTheme.orange
        case .filled: return Color.white.opacity(0.9)
        }
    }

    var capitalLabel: String {
        switch self {
        case .ready: return "FREE"
        case .submitted, .pending, .partial: return "RESERVED"
        case .filled: return "FILLED"
        }
    }
}

enum HoldingOrderIntent: String, CaseIterable {
    case live = "LIVE"
    case buyPending = "BUY PENDING"
    case sellPending = "SELL PENDING"

    var color: Color {
        switch self {
        case .live: return WealthTheme.grey
        case .buyPending: return WealthTheme.cyan
        case .sellPending: return WealthTheme.yellow
        }
    }
}
