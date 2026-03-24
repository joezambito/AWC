import SwiftUI

struct WealthHoldingsStatusBox: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(count == 0 ? "NO ACTIVE POSITIONS" : "\(count) ACTIVE POSITION\(count == 1 ? "" : "S")")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                solidPill(count == 0 ? "CLEAR" : "LIVE", color: count == 0 ? WealthTheme.green : WealthTheme.cyan, darkText: true)
            }

            Text(count == 0
                 ? "This changes when the AI starts buying or actively looking."
                 : "This updates as the AI adds buys, holds, or exits.")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(cardShell(cornerRadius: 16))
    }
}

struct WealthPhoneDashboardSectionView: View {
    let options: [String]
    let selected: String
    let activeColor: Color
    let holdingsCount: Int
    let showStatusBox: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DASHBOARD")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Phone-first command center")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Spacer()

                Text("\(holdingsCount) HOLDINGS")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(holdingsCount == 0 ? WealthTheme.red : .black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(holdingsCount == 0 ? Color.white.opacity(0.08) : WealthTheme.green)
                    .clipShape(Capsule())
            }
            .padding(8)
            .background(cardShell(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(WealthTheme.cyan.opacity(0.16), lineWidth: 0.9)
            )

            segmentBar(options: options, selected: selected, activeColor: activeColor) { value in
                onSelect(value)
            }

            if showStatusBox {
                WealthHoldingsStatusBox(count: holdingsCount)
            }
        }
    }
}
