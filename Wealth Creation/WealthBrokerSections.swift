import SwiftUI

struct WealthSystemDesktopBrokerSection: View {
    enum DesktopBrokerPanel: String, CaseIterable, Identifiable {
        case routing = "Routing"
        case sync = "Connection"
        case tuning = "Brain Tuning"
        case deck = "Status"

        var id: String { rawValue }
    }

    @ObservedObject var brokerStore = WealthBrokerStore.shared
    @ObservedObject var tuning = WealthBehaviorSettingsStore.shared
    @ObservedObject var syncStore = WealthSyncStore.shared
    @State var selectedPanel: DesktopBrokerPanel = .routing

    var body: some View {
        VStack(spacing: 12) {
            desktopBrokerHeader
            desktopBrokerTabs
            activeDesktopBrokerPanel
        }
    }
}
