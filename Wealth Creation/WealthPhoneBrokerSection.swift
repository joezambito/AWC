import SwiftUI

struct WealthPhoneBrokerSection: View {
    @ObservedObject var brokerStore = WealthBrokerStore.shared
    @ObservedObject var syncStore = WealthSyncStore.shared

    var reviewBrokers: [BrokerProfile] {
        let query = brokerStore.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return brokerStore.availableBrokers.filter { broker in
            broker.name != "IBKR" &&
            (
                query.isEmpty ||
                broker.name.localizedCaseInsensitiveContains(query) ||
                broker.mode.localizedCaseInsensitiveContains(query)
            )
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            activeBrokerCard
            brokerSearchCard
        }
    }
}
