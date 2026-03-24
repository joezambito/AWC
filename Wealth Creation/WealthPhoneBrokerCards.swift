import SwiftUI

extension WealthPhoneBrokerSection {
    var activeBrokerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACTIVE BROKER")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("IBKR stays active for balance, buys and sells. Search the others only when the brain recommends them.")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                solidPill(brokerStore.selectedBroker.name, color: WealthTheme.cyan, darkText: true)
            }

            HStack(spacing: 10) {
                compactSummaryCard(title: "Balance", value: WealthFormat.money(brokerStore.executionCashBalance), tint: WealthTheme.green)
                compactSummaryCard(title: "Paper", value: brokerStore.paperTradingEnabled ? "ON" : "OFF", tint: brokerStore.paperTradingEnabled ? WealthTheme.cyan : WealthTheme.grey)
                compactSummaryCard(title: "Live", value: brokerStore.liveTradingEnabled ? "ON" : "OFF", tint: brokerStore.liveTradingEnabled ? WealthTheme.orange : WealthTheme.grey)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("IBKR ACCOUNT ID")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                TextField("Enter account number", text: $brokerStore.ibkrAccountID)
                    .awcAccountFieldInputBehavior()
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(cardShell(cornerRadius: 18))
                    .onChange(of: brokerStore.ibkrAccountID) { _, _ in
                        brokerStore.persistRouting()
                    }
            }

            Toggle("Paper trading enabled", isOn: $brokerStore.paperTradingEnabled)
                .tint(WealthTheme.cyan)
                .foregroundColor(.white)
                .onChange(of: brokerStore.paperTradingEnabled) { _, _ in
                    brokerStore.persistRouting()
                }

            Toggle("Live trading enabled", isOn: $brokerStore.liveTradingEnabled)
                .tint(WealthTheme.orange)
                .foregroundColor(.white)
                .onChange(of: brokerStore.liveTradingEnabled) { _, _ in
                    brokerStore.persistRouting()
                }

            HStack(spacing: 10) {
                compactSummaryCard(title: "Host", value: syncStore.brokerHost, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Port", value: "\(syncStore.brokerPort)", tint: WealthTheme.orange)
                compactSummaryCard(title: "API", value: syncStore.syncStatus, tint: apiTint)
            }

            HStack(spacing: 10) {
                Button {
                    syncStore.connectBrokerAPI()
                } label: {
                    actionLabel("TEST TWS", colors: [WealthTheme.cyan, WealthTheme.green], textColor: .black)
                }
                .buttonStyle(.plain)

                Button {
                    syncStore.disconnectBrokerAPI()
                } label: {
                    Text("DISCONNECT")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            WealthLiveMarketDebugPanel(compact: true)
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.cyan, secondaryTint: WealthTheme.green))
    }
}
