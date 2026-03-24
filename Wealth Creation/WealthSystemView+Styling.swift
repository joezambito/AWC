import SwiftUI

extension SystemView {
    func desktopHeaderBadge(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.54))
            Text(value.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.14), lineWidth: 0.8)
                )
        )
    }

    func desktopLabel(for item: SystemTab) -> String {
        switch item {
        case .parameters:
            return "System"
        case .brain:
            return "Brain"
        case .events:
            return "Event Log"
        case .ai:
            return "Brain Control"
        case .brokers:
            return "Brokers"
        case .help:
            return "Help"
        }
    }

    func desktopTabTint(for item: SystemTab) -> Color {
        switch item {
        case .parameters:
            return WealthTheme.orange
        case .brain:
            return WealthTheme.purple
        case .events:
            return WealthTheme.orange
        case .ai:
            return WealthTheme.cyan
        case .brokers:
            return WealthTheme.green
        case .help:
            return WealthTheme.purple
        }
    }

    func phoneTabTint(for item: SystemTab) -> Color {
        switch item {
        case .parameters:
            return WealthTheme.blue.opacity(0.85)
        case .brain:
            return WealthTheme.purple
        case .events:
            return WealthTheme.orange
        case .ai:
            return WealthTheme.cyan
        case .brokers:
            return WealthTheme.cyan.opacity(0.78)
        case .help:
            return WealthTheme.purple
        }
    }
}
