import SwiftUI

extension WealthRootView {
    var desktopSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                brandLogoTile(size: 50, cornerRadius: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ZULUGAMES")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Autonomous Wealth Creation")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.cyan)
                }
            }
            .padding(12)
            .background(cardShell(cornerRadius: 20))

            VStack(spacing: 8) {
                ForEach(MainTab.allCases) { tab in
                    let selected = tab == mainTab
                    Button {
                        mainTab = tab
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .black))
                                .frame(width: 20)

                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .black, design: .rounded))

                            Spacer()

                            if tab == .activity, activityBadgeCount > 0 {
                                Text("\(activityBadgeCount)")
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(WealthTheme.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(selected ? .black : .white.opacity(0.82))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selected ? desktopTabSelectionTint(for: tab) : Color.white.opacity(0.035))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke((selected ? desktopTabSelectionTint(for: tab) : Color.white).opacity(0.10), lineWidth: 0.8)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(cardShell(cornerRadius: 22))

            VStack(spacing: 10) {
                compactSummaryCard(title: "Route", value: brokerStore.selectedBroker.name, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Brain", value: engine.brainSnapshot.mode.rawValue, tint: engine.brainSnapshot.mode.color)
                compactSummaryCard(title: "Model", value: engine.brainSnapshot.modelReadiness, tint: WealthTheme.green)
                compactSummaryCard(title: "Data", value: engine.brainSnapshot.dataReadiness, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Regime", value: engine.brainSnapshot.regime.rawValue, tint: engine.brainSnapshot.regime.color)
                compactSummaryCard(title: "Sync", value: syncStore.syncStatus, tint: WealthTheme.green)
            }

            Spacer()
        }
    }

    func desktopTabSelectionTint(for tab: MainTab) -> Color {
        switch tab {
        case .dashboard: return WealthTheme.white
        case .activity: return WealthTheme.orange
        case .markets: return WealthTheme.cyan
        case .campaign: return WealthTheme.purple
        case .system: return WealthTheme.green
        }
    }
}
