import SwiftUI

func wealthDesktopBrokerHeaderRow(title: String, badge: String, tint: Color) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundColor(.white)
        Spacer()
        solidPill(badge, color: tint, darkText: true)
    }
}

func wealthDesktopBrokerInfoBlock(rows: [(String, String, Color)]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            HStack(alignment: .top) {
                Text(row.0)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
                Spacer()
                Text(row.1)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(row.2)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
    .padding(14)
    .background(cardShell(cornerRadius: 18))
}
