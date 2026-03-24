import SwiftUI

struct WealthDesktopBrokerRoutePriorityCard: View {
    @ObservedObject var brokerStore: WealthBrokerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            wealthDesktopBrokerHeaderRow(title: "EXECUTION PRIORITY", badge: "LOWEST FEE", tint: WealthTheme.green)

            Toggle("Cheapest broker first", isOn: $brokerStore.lowestFeeFirst)
                .tint(WealthTheme.green)
                .foregroundColor(.white)
                .onChange(of: brokerStore.lowestFeeFirst) { _, _ in brokerStore.persistRouting() }

            Toggle("Smart routing", isOn: $brokerStore.smartRouting)
                .tint(WealthTheme.cyan)
                .foregroundColor(.white)
                .onChange(of: brokerStore.smartRouting) { _, _ in brokerStore.persistRouting() }

            wealthDesktopBrokerInfoBlock(
                rows: [
                    ("Current Route", brokerStore.currentRouteLabel, WealthTheme.cyan),
                    ("Mode", brokerStore.selectedBroker.mode, WealthTheme.gold),
                    ("Safety", "Smart routing prefers trusted brokers with the lowest fee first.", .white.opacity(0.9))
                ]
            )
        }
    }
}

struct WealthDesktopBrokerReadinessCard: View {
    @ObservedObject var brokerStore: WealthBrokerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            wealthDesktopBrokerHeaderRow(
                title: "EXECUTION READINESS",
                badge: brokerStore.readinessBadge,
                tint: brokerStore.liveTradingEnabled ? WealthTheme.orange : WealthTheme.cyan
            )

            wealthDesktopBrokerInfoBlock(
                rows: [
                    ("Route", brokerStore.currentRouteLabel, WealthTheme.cyan),
                    ("Execution", brokerStore.executionModeLabel, brokerStore.liveTradingEnabled ? WealthTheme.orange : WealthTheme.cyan),
                    ("Fee Model", "Manual Broker Estimate", WealthTheme.cyan),
                    ("Profit Guard", "Net profit must clear costs with edge", .white.opacity(0.9)),
                    ("Readiness", brokerStore.liveTradingEnabled ? "Broker path is connected and live execution is enabled." : "Broker path is connected, but execution remains paper-only until live mode is enabled.", brokerStore.liveTradingEnabled ? WealthTheme.orange : WealthTheme.cyan)
                ]
            )
        }
    }
}

struct WealthDesktopBrokerConnectionCard: View {
    @ObservedObject var brokerStore: WealthBrokerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            wealthDesktopBrokerHeaderRow(title: "CONNECTION", badge: brokerStore.selectedBroker.name, tint: WealthTheme.green)

            VStack(alignment: .leading, spacing: 8) {
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
                    .onChange(of: brokerStore.ibkrAccountID) { _, _ in brokerStore.persistRouting() }
            }

            Toggle("Paper trading enabled", isOn: $brokerStore.paperTradingEnabled)
                .tint(WealthTheme.cyan)
                .foregroundColor(.white)
                .onChange(of: brokerStore.paperTradingEnabled) { _, _ in brokerStore.persistRouting() }

            Toggle("Live trading enabled", isOn: $brokerStore.liveTradingEnabled)
                .tint(WealthTheme.orange)
                .foregroundColor(.white)
                .onChange(of: brokerStore.liveTradingEnabled) { _, _ in brokerStore.persistRouting() }

            HStack(spacing: 10) {
                infoCell(label: "Account", value: brokerStore.ibkrAccountID.isEmpty ? "NOT SET" : brokerStore.ibkrAccountID, tint: brokerStore.ibkrAccountID.isEmpty ? WealthTheme.grey : WealthTheme.cyan)
                infoCell(label: "Paper", value: brokerStore.paperTradingEnabled ? "ON" : "OFF", tint: brokerStore.paperTradingEnabled ? WealthTheme.cyan : WealthTheme.grey)
                infoCell(label: "Live", value: brokerStore.liveTradingEnabled ? "ON" : "OFF", tint: brokerStore.liveTradingEnabled ? WealthTheme.orange : WealthTheme.grey)
            }
        }
    }
}

struct WealthDesktopBrokerStatusCard: View {
    @ObservedObject var brokerStore: WealthBrokerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            wealthDesktopBrokerHeaderRow(
                title: "STATUS",
                badge: brokerStore.selectedBroker.trusted ? "TRUSTED" : "CHECK ROUTE",
                tint: brokerStore.selectedBroker.trusted ? WealthTheme.green : WealthTheme.orange
            )

            wealthDesktopBrokerInfoBlock(
                rows: [
                    ("Broker Safety", brokerStore.selectedBroker.safety, brokerStore.selectedBroker.trusted ? WealthTheme.green : WealthTheme.orange),
                    ("Fee Rank", "#\(brokerStore.selectedBroker.feeScore)", WealthTheme.cyan),
                    ("Selection Logic", brokerStore.smartRouting ? "The brain chooses the cheapest trusted broker that can fill the route safely." : "The app stays on the current broker until you change the route.", .white.opacity(0.9))
                ]
            )
        }
    }
}
