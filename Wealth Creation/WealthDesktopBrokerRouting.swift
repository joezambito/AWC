import SwiftUI

struct WealthSystemDesktopRouteSection: View {
    @ObservedObject var brokerStore = WealthBrokerStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WealthDesktopBrokerRoutePriorityCard(brokerStore: brokerStore)
            WealthDesktopBrokerReadinessCard(brokerStore: brokerStore)
            WealthDesktopBrokerConnectionCard(brokerStore: brokerStore)
            WealthDesktopBrokerStatusCard(brokerStore: brokerStore)
            WealthDesktopBrokerRegistrySearchCard(brokerStore: brokerStore)
        }
        .padding(14)
        .background(cardShell(cornerRadius: 24))
    }
}
