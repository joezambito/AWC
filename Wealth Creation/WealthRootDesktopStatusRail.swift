import SwiftUI

struct WealthDesktopStatusRailSection: View {
    let readinessBadge: String
    let routeLabel: String
    let lastMessage: String
    let isAuthorized: Bool
    let lastPhoneSyncText: String
    let lastMacSyncText: String
    let brainMode: String
    let brainModeTint: Color
    let regime: String
    let regimeTint: Color
    let liveMode: Bool
    let macBridgeEnabled: Bool
    let cloudSyncEnabled: Bool
    let activityCount: Int
    let queuedOpenCount: Int

    var body: some View {
        VStack(spacing: 12) {
            sectionShell(title: "DESKTOP STATUS", subtitle: "Mac-facing live control view", trailing: readinessBadge)

            VStack(spacing: 10) {
                compactSummaryCard(title: "Broker Route", value: routeLabel, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Alerts", value: lastMessage.uppercased(), tint: isAuthorized ? WealthTheme.green : WealthTheme.orange)
                compactSummaryCard(title: "Phone Sync", value: lastPhoneSyncText, tint: WealthTheme.cyan)
                compactSummaryCard(title: "Mac Sync", value: lastMacSyncText, tint: WealthTheme.green)
                compactSummaryCard(title: "Brain Mode", value: brainMode, tint: brainModeTint)
                compactSummaryCard(title: "Regime", value: regime, tint: regimeTint)
            }

            WealthDesktopExecutionRailView(
                liveMode: liveMode,
                macBridgeEnabled: macBridgeEnabled,
                cloudSyncEnabled: cloudSyncEnabled,
                activityCount: activityCount,
                queuedOpenCount: queuedOpenCount
            )
        }
    }
}
