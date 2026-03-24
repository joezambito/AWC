import SwiftUI

extension WealthSystemParametersSection {
    var desktopRefreshAndAlertsSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("REFRESH CYCLE")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Light monitor and heavy scan timing for the desktop brain path.")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                    Spacer()
                    solidPill("DESKTOP", color: WealthTheme.orange, darkText: true)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LIGHT REFRESH")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.62))
                        minutesField(value: $lightRefreshMinutes, tint: WealthTheme.cyan)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("HEAVY REFRESH")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.62))
                        minutesField(value: $heavyRefreshMinutes, tint: WealthTheme.orange)
                    }
                }
            }
            .padding(12)
            .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.cyan, secondaryTint: WealthTheme.orange))
            .frame(maxWidth: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ALERT STATUS")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Quick desktop view of phone notification readiness and last alert state.")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(WealthTheme.grey)
                    }
                    Spacer()
                    solidPill(notifications.isAuthorized ? "ENABLED" : "WAITING", color: notifications.isAuthorized ? WealthTheme.green : WealthTheme.orange, darkText: true)
                }

                HStack(spacing: 10) {
                    compactSummaryCard(title: "Notifications", value: notifications.isAuthorized ? "ON" : "OFF", tint: notifications.isAuthorized ? WealthTheme.green : WealthTheme.orange)
                    compactSummaryCard(title: "Speed", value: protection.speedAlertEnabled ? "ON" : "OFF", tint: WealthTheme.cyan)
                    compactSummaryCard(title: "Capital", value: protection.capitalAlertEnabled ? "ON" : "OFF", tint: WealthTheme.purple)
                }

                Text(notifications.lastMessage.isEmpty ? "Idle" : notifications.lastMessage)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(cardShell(cornerRadius: 18))
            }
            .padding(12)
            .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.purple, secondaryTint: WealthTheme.green))
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
