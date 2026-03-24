import SwiftUI

extension WealthSystemDesktopBrokerSection {
    var desktopBrokerDeck: some View {
        VStack(spacing: 12) {
            sectionShell(title: "DESKTOP BROKER DECK", subtitle: "Mac-only route, sync and execution pulse", trailing: brokerStore.readinessBadge)

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 12) {
                    wealthSystemTuningStatCard(title: "ROUTE", value: brokerStore.selectedBroker.name, tint: WealthTheme.cyan)
                    wealthSystemTuningStatCard(title: "FEE", value: brokerStore.selectedBroker.feeLabel, tint: WealthTheme.green)
                    wealthSystemTuningStatCard(title: "MODE", value: brokerStore.executionModeLabel, tint: brokerStore.liveTradingEnabled ? WealthTheme.orange : WealthTheme.cyan)
                }

                VStack(spacing: 12) {
                    wealthSystemTuningStatCard(title: "SYNC", value: syncStore.syncStatus, tint: WealthTheme.green)
                    wealthSystemTuningStatCard(title: "MAC", value: WealthFormat.ageText(syncStore.lastMacSync), tint: WealthTheme.purple)
                    wealthSystemTuningStatCard(title: "PHONE", value: WealthFormat.ageText(syncStore.lastPhoneSync), tint: WealthTheme.orange)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("ROUTE LOGIC")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                    Text(brokerStore.smartRouting ? "The brain prefers the cheapest trusted route that can fill safely in the current session." : "The app remains on the pinned route until you manually move the broker path.")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        solidPill(brokerStore.selectedBroker.trusted ? "TRUSTED" : "CHECK", color: brokerStore.selectedBroker.trusted ? WealthTheme.green : WealthTheme.orange, darkText: true)
                        solidPill(syncStore.liveMode ? "LIVE LINK" : "PAPER LINK", color: syncStore.liveMode ? WealthTheme.orange : WealthTheme.cyan, darkText: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(cardShell(cornerRadius: 22))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("RECENT BROKER EVENTS")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))

                ForEach(Array(syncStore.syncLog.prefix(3))) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(WealthTheme.cyan)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(WealthFormat.ageText(item.timestamp))
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(WealthTheme.grey)
                            }

                            Text(item.detail)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.82))
                        }
                    }
                    .padding(12)
                    .background(cardShell(cornerRadius: 18))
                }
            }
            .padding(14)
            .background(cardShell(cornerRadius: 24))
        }
    }
}
