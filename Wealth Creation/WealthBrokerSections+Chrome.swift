import SwiftUI

extension WealthSystemDesktopBrokerSection {
    var desktopBrokerHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [WealthTheme.purple.opacity(0.16), WealthTheme.cyan.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(WealthTheme.cyan.opacity(0.20), lineWidth: 0.8)
                    )
                    .frame(width: 34, height: 34)

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(WealthTheme.cyan)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("BROKER CONTROLS")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Brokers, fees, routing and execution limits")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }

            Spacer()

            solidPill(syncStore.syncStatus.uppercased(), color: WealthTheme.green, darkText: true)
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

    var desktopBrokerTabs: some View {
        HStack(spacing: 8) {
            ForEach(DesktopBrokerPanel.allCases) { panel in
                Button {
                    selectedPanel = panel
                } label: {
                    Text(panel.rawValue.uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(selectedPanel == panel ? .black : .white.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selectedPanel == panel ? brokerPanelTint(for: panel) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke((selectedPanel == panel ? brokerPanelTint(for: panel) : Color.white).opacity(0.10), lineWidth: 0.8)
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

    @ViewBuilder
    var activeDesktopBrokerPanel: some View {
        switch selectedPanel {
        case .routing:
            WealthSystemDesktopRouteSection()
        case .sync:
            WealthSystemDesktopSyncSection()
        case .tuning:
            desktopAITuningCard
        case .deck:
            desktopBrokerDeck
        }
    }

    func brokerPanelTint(for panel: DesktopBrokerPanel) -> Color {
        switch panel {
        case .routing: return WealthTheme.cyan
        case .sync: return WealthTheme.orange
        case .tuning: return WealthTheme.purple
        case .deck: return WealthTheme.green
        }
    }
}
