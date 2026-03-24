import SwiftUI

extension WealthRootView {
    @ViewBuilder
    var desktopSupplementalRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                switch mainTab {
                case .dashboard:
                    desktopGraphDeck
                    WealthDesktopStatusRailSection(
                        readinessBadge: brokerStore.readinessBadge,
                        routeLabel: brokerStore.currentRouteLabel,
                        lastMessage: notificationStore.lastMessage,
                        isAuthorized: notificationStore.isAuthorized,
                        lastPhoneSyncText: WealthFormat.ageText(syncStore.lastPhoneSync),
                        lastMacSyncText: WealthFormat.ageText(syncStore.lastMacSync),
                        brainMode: engine.brainSnapshot.mode.rawValue,
                        brainModeTint: engine.brainSnapshot.mode.color,
                        regime: engine.brainSnapshot.regime.rawValue,
                        regimeTint: engine.brainSnapshot.regime.color,
                        liveMode: syncStore.liveMode,
                        macBridgeEnabled: syncStore.macBridgeEnabled,
                        cloudSyncEnabled: syncStore.cloudSyncEnabled,
                        activityCount: activityCount,
                        queuedOpenCount: pendingOpportunities.filter { !$0.sessionState.canTradeNow }.count
                    )
                    desktopHistoryRail
                    desktopCommandDeck
                case .activity:
                    desktopHistoryRail
                    desktopCommandDeck
                case .markets:
                    desktopGraphDeck
                    desktopCommandDeck
                case .campaign:
                    WealthBrainSummaryPanel(snapshot: engine.brainSnapshot)
                    desktopCommandDeck
                case .system:
                    WealthSystemStatusRailView()
                    WealthBrainSummaryPanel(snapshot: engine.brainSnapshot)
                }
            }
            .padding(.bottom, 24)
        }
    }
}
