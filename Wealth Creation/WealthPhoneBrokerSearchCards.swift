import SwiftUI

extension WealthPhoneBrokerSection {
    var brokerSearchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("BROKER SEARCH")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                solidPill("REVIEW", color: WealthTheme.purple, darkText: true)
            }

            TextField("Search broker name", text: $brokerStore.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(cardShell(cornerRadius: 18))

            if reviewBrokers.isEmpty {
                Text("No other broker is running live. Search here after a brain recommendation, then choose whether to keep IBKR or switch.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(cardShell(cornerRadius: 18))
            } else {
                VStack(spacing: 10) {
                    ForEach(reviewBrokers, id: \.name) { broker in
                        brokerCard(for: broker)
                    }
                }
            }
        }
        .padding(14)
        .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.purple, secondaryTint: WealthTheme.cyan))
    }

    func brokerCard(for broker: BrokerProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(broker.name)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(broker.feeLabel) · \(broker.mode)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                solidPill("OFF", color: WealthTheme.grey, darkText: true)
            }

            HStack(spacing: 10) {
                compactSummaryCard(title: "Safety", value: broker.safety.uppercased(), tint: broker.trusted ? WealthTheme.green : WealthTheme.orange)
                compactSummaryCard(title: "Fee", value: broker.feeLabel, tint: WealthTheme.cyan)
            }

            HStack(spacing: 10) {
                Button {
                    brokerStore.searchQuery = ""
                } label: {
                    actionLabel("KEEP IBKR", colors: [WealthTheme.white, WealthTheme.cyan], textColor: .black)
                }
                .buttonStyle(.plain)

                Button {
                    brokerStore.select(broker)
                    brokerStore.searchQuery = ""
                } label: {
                    actionLabel("MAKE ACTIVE", colors: [WealthTheme.green, WealthTheme.cyan], textColor: .black)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(cardShell(cornerRadius: 20))
    }

    func actionLabel(_ title: String, colors: [Color], textColor: Color) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
    }

    var apiTint: Color {
        if syncStore.syncStatus.contains("FAILED") { return WealthTheme.red }
        if syncStore.syncStatus.contains("TWS") { return WealthTheme.green }
        return WealthTheme.grey
    }
}
