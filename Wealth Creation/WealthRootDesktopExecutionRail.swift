import SwiftUI

struct WealthDesktopExecutionRailView: View {
    let liveMode: Bool
    let macBridgeEnabled: Bool
    let cloudSyncEnabled: Bool
    let activityCount: Int
    let queuedOpenCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MAC EXECUTION")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                solidPill(liveMode ? "LIVE" : "PAPER", color: liveMode ? WealthTheme.orange : WealthTheme.cyan, darkText: true)
            }

            HStack(spacing: 10) {
                miniReferenceCard(
                    title: "Mac Bridge",
                    value: macBridgeEnabled ? "ON" : "OFF",
                    accent: macBridgeEnabled ? WealthTheme.green : WealthTheme.grey,
                    tag: macBridgeEnabled ? "READY" : "OFF"
                )
                miniReferenceCard(
                    title: "Cloud Sync",
                    value: cloudSyncEnabled ? "ON" : "OFF",
                    accent: cloudSyncEnabled ? WealthTheme.cyan : WealthTheme.grey,
                    tag: cloudSyncEnabled ? "LIVE" : "OFF"
                )
            }

            HStack(spacing: 10) {
                miniReferenceCard(
                    title: "Pending",
                    value: "\(activityCount)",
                    accent: activityCount > 0 ? WealthTheme.orange : WealthTheme.green,
                    tag: activityCount > 0 ? "ACTIVE" : "CLEAR"
                )
                miniReferenceCard(
                    title: "Queued Open",
                    value: "\(queuedOpenCount)",
                    accent: WealthTheme.gold,
                    tag: "WATCH"
                )
            }
        }
        .padding(12)
        .background(cardShell(cornerRadius: 24))
    }
}
