import SwiftUI

struct ActivityMoment: Identifiable {
    let id: String
    let title: String
    let detail: String
    let tint: Color
}

enum MainTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case activity = "Activity"
    case markets = "Markets"
    case campaign = "Campaign"
    case system = "System"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .activity: return "arrow.left.arrow.right.circle.fill"
        case .markets: return "chart.line.uptrend.xyaxis"
        case .campaign: return "scope"
        case .system: return "gearshape.fill"
        }
    }

    var accent: Color {
        switch self {
        case .dashboard: return WealthTheme.cyan
        case .activity: return WealthTheme.orange
        case .markets: return WealthTheme.green
        case .campaign: return WealthTheme.purple
        case .system: return Color.white.opacity(0.92)
        }
    }
}

enum DashboardMode: String, CaseIterable, Identifiable {
    case holdings = "Current Holdings"
    case livePicks = "AI Live"

    var id: String { rawValue }
}
