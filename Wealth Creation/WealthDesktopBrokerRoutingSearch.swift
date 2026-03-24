import SwiftUI

struct WealthDesktopBrokerRegistrySearchCard: View {
    @ObservedObject var brokerStore: WealthBrokerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            wealthDesktopBrokerHeaderRow(title: "REGISTRY SEARCH", badge: brokerStore.pinnedBroker().name, tint: WealthTheme.green)

            TextField("Search trusted broker if needed", text: $brokerStore.searchQuery)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(cardShell(cornerRadius: 18))
                .onChange(of: brokerStore.searchQuery) { _, _ in brokerStore.updateSearchResults() }

            if brokerStore.searchQuery.isEmpty {
                Text("IBKR stays pinned by default. Search only if you need another trusted route.")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            } else if brokerStore.brokerResults.isEmpty {
                Text("No trusted broker match found.")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.red)
            } else {
                ForEach(brokerStore.brokerResults) { broker in
                    Button {
                        brokerStore.select(broker)
                        WealthEngineStore.shared.refresh(mode: .heavy)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(broker.name)
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text("\(broker.feeLabel) · \(broker.mode)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(WealthTheme.cyan)
                            }
                            Spacer()
                            solidPill("TRUSTED", color: WealthTheme.green, darkText: true)
                        }
                        .padding(14)
                        .background(cardShell(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
