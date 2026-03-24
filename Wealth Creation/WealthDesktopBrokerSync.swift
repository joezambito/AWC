import SwiftUI

struct WealthSystemDesktopSyncSection: View {
    @ObservedObject private var syncStore = WealthSyncStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            toggleRow
            hostPortRow
            liveModeToggle
            brokerActionRow
            syncActionRow
            summaryRow
            WealthLiveMarketDebugPanel(compact: false)
            historySection
        }
        .padding(14)
        .background(cardShell(cornerRadius: 26))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("MAC / PHONE SYNC")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Shared core state for phone-first control with Mac support.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(WealthTheme.grey)
            }
            Spacer()
            solidPill(syncStore.syncStatus, color: WealthTheme.green, darkText: true)
        }
    }

    private var toggleRow: some View {
        HStack(spacing: 12) {
            Toggle("Mac bridge", isOn: $syncStore.macBridgeEnabled)
                .tint(WealthTheme.cyan)
                .foregroundColor(.white)
            Toggle("Cloud sync", isOn: $syncStore.cloudSyncEnabled)
                .tint(WealthTheme.green)
                .foregroundColor(.white)
        }
    }

    private var hostPortRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("BROKER HOST")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                TextField("", text: $syncStore.brokerHost)
                    .awcHostFieldInputBehavior()
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(cardShell(cornerRadius: 18))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("BROKER PORT")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                TextField("", value: $syncStore.brokerPort, format: .number)
                    .keyboardType(.numberPad)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(cardShell(cornerRadius: 18))
            }
        }
    }

    private var liveModeToggle: some View {
        Toggle("Live mode", isOn: $syncStore.liveMode)
            .tint(WealthTheme.orange)
            .foregroundColor(.white)
    }

    private var brokerActionRow: some View {
        HStack(spacing: 10) {
            wealthSystemSyncActionButton("TEST TWS") { syncStore.connectBrokerAPI() }
            wealthSystemSyncActionButton("DISCONNECT") { syncStore.disconnectBrokerAPI() }
        }
    }

    private var syncActionRow: some View {
        HStack(spacing: 10) {
            wealthSystemSyncActionButton("SYNC PHONE") { syncStore.syncFromPhone() }
            wealthSystemSyncActionButton("SYNC MAC") { syncStore.syncFromMac() }
            wealthSystemSyncActionButton("SYNC ALL") { syncStore.syncEverything() }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            infoCell(label: "Phone", value: WealthFormat.ageText(syncStore.lastPhoneSync), tint: WealthTheme.cyan)
            infoCell(label: "Mac", value: WealthFormat.ageText(syncStore.lastMacSync), tint: WealthTheme.green)
            infoCell(label: "Mode", value: syncStore.liveMode ? "LIVE" : "PAPER", tint: syncStore.liveMode ? WealthTheme.orange : WealthTheme.cyan)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SYNC HISTORY")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.62))

            ForEach(syncStore.syncLog) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(WealthTheme.cyan)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.title)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                            Text(WealthFormat.ageText(item.timestamp))
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(WealthTheme.grey)
                        }

                        Text(item.detail)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.82))
                    }
                }
                .padding(12)
                .background(cardShell(cornerRadius: 18))
            }
        }
    }
}
