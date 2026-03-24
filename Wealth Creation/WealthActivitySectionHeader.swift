import SwiftUI

extension View {
    func sectionHeader(
        title: String,
        subtitle: String,
        badge: String,
        badgeColor: Color,
        darkBadgeText: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(title == "RECENT COMPLETED" ? Color.white.opacity(0.72) : WealthTheme.purple)
                }

                Spacer()

                solidPill(badge, color: badgeColor, darkText: darkBadgeText)
            }
            .padding(.horizontal, 12)
            .padding(.top, title == "AI LIVE" ? 12 : 9)
        }
    }
}
