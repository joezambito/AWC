import SwiftUI

struct WealthRootView: View {
    private enum StorageKey {
        static let lightRefreshMinutes = "awc_scan_refresh_light_minutes"
        static let heavyRefreshMinutes = "awc_scan_refresh_heavy_minutes"
    }

    @ObservedObject var portfolio = WealthPortfolioStore.shared
    @ObservedObject var engine = WealthEngineStore.shared
    @ObservedObject var brokerStore = WealthBrokerStore.shared
    @ObservedObject var notificationStore = WealthNotificationStore.shared
    @ObservedObject var protection = WealthProtectionSettingsStore.shared
    @ObservedObject var syncStore = WealthSyncStore.shared

    @AppStorage(StorageKey.lightRefreshMinutes) var lightRefreshMinutes = WealthEngineStore.defaultSoftRefreshMinutes
    @AppStorage(StorageKey.heavyRefreshMinutes) var heavyRefreshMinutes = WealthEngineStore.defaultHeavyRefreshMinutes

    @State var mainTab: MainTab
    @State var dashboardMode: DashboardMode = .holdings
    @State var selectedHolding: Holding?
    @State var selectedOpportunity: Opportunity?

    init() {
        _mainTab = State(initialValue: WealthSimulatorSessionSupport.defaultRootTab)
    }

    var body: some View {
        Group {
            if hasDesktopLayout {
                desktopRootShell
            } else {
                phoneSafeRoot
            }
        }
    }
}
