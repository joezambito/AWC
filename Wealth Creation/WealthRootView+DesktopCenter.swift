import SwiftUI

extension WealthRootView {
    var desktopCenterColumn: some View {
        VStack(spacing: 12) {
            desktopToolbar

            Group {
                if mainTab == .system {
                    mainContent
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 14) {
                            if mainTab == .dashboard {
                                headerCard
                                dashboardSection
                            } else {
                                mainContent
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.bottom, 24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    var desktopToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(desktopSectionTitle)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(desktopSectionSubtitle)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }

            Spacer()

            desktopToolbarButton("Graphs", icon: "waveform.path.ecg") {
                mainTab = .dashboard
                dashboardMode = .livePicks
            }
            desktopToolbarButton("System", icon: "gearshape.fill") {
                mainTab = .system
            }
            desktopToolbarButton("Markets", icon: "chart.line.uptrend.xyaxis") {
                mainTab = .markets
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }

    func desktopToolbarButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [WealthTheme.white, WealthTheme.cyan.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    var desktopSectionTitle: String {
        switch mainTab {
        case .dashboard: return "Dashboard"
        case .activity: return "Activity Feed"
        case .markets: return "Markets"
        case .campaign: return "Campaign"
        case .system: return "System Control"
        }
    }

    var desktopSectionSubtitle: String {
        switch mainTab {
        case .dashboard:
            return "Desktop command surface with live brain graphs, history and route status"
        case .activity:
            return "Buys, sells, fills and broker events"
        case .markets:
            return "Scan universe, share prices and market routing"
        case .campaign:
            return "Profit-only progress across your goal stack"
        case .system:
            return "Parameters, brain controls, broker routing and guide access"
        }
    }
}
