import SwiftUI

extension WealthPhoneBrokerSection {
    private var twsStatusValue: String {
        syncStore.isTWSConnectedForQuotes ? "ONLINE" : "OFFLINE"
    }

    private var twsStatusTint: Color {
        syncStore.isTWSConnectedForQuotes ? WealthTheme.green : WealthTheme.red
    }

    var activeBrokerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACTIVE BROKER")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Phone can use direct TWS access when the broker endpoint points at your Mac.")
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

            HStack(alignment: .top, spacing: 10) {
                compactSummaryCard(title: "TWS", value: twsStatusValue, tint: twsStatusTint)
                compactSummaryCard(title: "API", value: syncStore.syncStatus, tint: apiTint)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("BROKER ENDPOINT")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                    Spacer()
                    Button {
                        endpointFieldsLocked.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: endpointFieldsLocked ? "lock.fill" : "lock.open.fill")
                                .font(.system(size: 10, weight: .black))
                            Text(endpointFieldsLocked ? "LOCKED" : "EDITING")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                        }
                        .foregroundColor(endpointFieldsLocked ? WealthTheme.grey : WealthTheme.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(cardShell(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("HOST")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                    TextField("Broker host", text: $syncStore.brokerHost)
                        .awcHostFieldInputBehavior()
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(cardShell(cornerRadius: 18))
                        .disabled(endpointFieldsLocked)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("PORT")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                    TextField("Broker port", value: $syncStore.brokerPort, format: .number)
                        .awcNumberPadInputBehavior()
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(cardShell(cornerRadius: 18))
                        .disabled(endpointFieldsLocked)
                }
            }

            HStack(spacing: 10) {
                wealthSystemSyncActionButton("TEST TWS") { syncStore.connectBrokerAPI() }
                wealthSystemSyncActionButton("DISCONNECT") { syncStore.disconnectBrokerAPI() }
            }

            Text("Point host to your Mac, keep the matching TWS port, then test the connection from here.")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(WealthTheme.grey)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardShell(cornerRadius: 18))

            WealthLiveMarketDebugPanel(compact: true)
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.cyan, secondaryTint: WealthTheme.green))
    }
}
