import SwiftUI

extension SystemView {
    var desktopSystemShell: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 1040

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    desktopHeaderCard
                    desktopSystemTabs

                    if isWide && tab != .help {
                        HStack(alignment: .top, spacing: 12) {
                            activeSystemView
                                .frame(maxWidth: .infinity, alignment: .top)
                            WealthSystemStatusRailView()
                                .frame(width: 300, alignment: .top)
                        }
                    } else {
                        activeSystemView
                    }
                }
                .frame(maxWidth: 1260)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
        }
    }

    var desktopSystemTabs: some View {
        HStack(spacing: 8) {
            ForEach(SystemTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    Text(desktopLabel(for: item))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(tab == item ? .black : .white.opacity(0.84))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(tab == item ? desktopTabTint(for: item) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke((tab == item ? desktopTabTint(for: item) : Color.white).opacity(0.10), lineWidth: 0.8)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }

    var desktopHeaderCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [WealthTheme.cyan.opacity(0.18), WealthTheme.blue.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(WealthTheme.cyan.opacity(0.28), lineWidth: 0.9)
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(WealthTheme.cyan)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("SYSTEM CONTROL DECK")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Mac parameters, brain depth, broker routing and guide access")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }

                Spacer()

                solidPill("ONLINE", color: WealthTheme.green, darkText: true)
            }

            HStack(spacing: 10) {
                desktopHeaderBadge(title: "Tab", value: desktopLabel(for: tab), tint: desktopTabTint(for: tab))
                desktopHeaderBadge(title: "Mode", value: tab == .help ? "GUIDE" : "CONTROL", tint: tab == .help ? WealthTheme.purple : WealthTheme.cyan)
                desktopHeaderBadge(title: "Profile", value: "MAC", tint: WealthTheme.orange)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
}
