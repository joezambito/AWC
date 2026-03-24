import SwiftUI

enum WealthAIStackStatus: String {
    case active = "ACTIVE"
    case foundation = "FOUNDATION"
    case planned = "PLANNED"
    case external = "EXTERNAL"

    var color: Color {
        switch self {
        case .active:
            return WealthTheme.green
        case .foundation:
            return WealthTheme.cyan
        case .planned:
            return WealthTheme.orange
        case .external:
            return WealthTheme.purple
        }
    }
}

struct WealthAIStackItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let note: String
    let status: WealthAIStackStatus
}

struct WealthAIStackGroup: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let tint: Color
    let items: [WealthAIStackItem]
}

enum WealthAIStackCatalog {
    static let groups: [WealthAIStackGroup] =
        coreGroups +
        intelligenceGroups +
        portfolioGroups +
        governanceGroups
}
