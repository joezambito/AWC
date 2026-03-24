import SwiftUI

struct WealthSystemAIStatusPanel: View {
    let activationCycleComplete: Bool
    let activationStage: Int
    let activationStageTotal: Int
    let lightRefreshMinutes: Int
    let heavyRefreshMinutes: Int

    @ObservedObject private var protection = WealthProtectionSettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI STATUS")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    WealthEngineStore.shared.forceRefreshNow()
                } label: {
                    Text("FORCE REFRESH")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(activationCycleComplete ? WealthTheme.green : WealthTheme.cyan)
                        )
                }
                .buttonStyle(.plain)
                solidPill(
                    activationCycleComplete ? "READY" : "STAGED",
                    color: activationCycleComplete ? WealthTheme.green : WealthTheme.cyan,
                    darkText: true
                )
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cycle")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(activationCycleComplete ? "DONE" : "\(activationStage)/\(activationStageTotal)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(WealthTheme.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(sectionGlowShell(cornerRadius: 11, tint: WealthTheme.cyan))
                compactSummaryCard(title: "Soft", value: "\(lightRefreshMinutes)m", tint: WealthTheme.cyan)
                compactSummaryCard(title: "Heavy", value: "\(heavyRefreshMinutes)m", tint: WealthTheme.orange)
            }

            Text("Phone waits for the dashboard to settle, then runs the brain through startup, quick, soft, heavy, and deep passes. Mac keeps the deeper manual controls.")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(cardShell(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 8) {
                Text("BRAIN ALERTS")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                wealthSystemToggleCard(
                    title: "SPEED ALERT",
                    subtitle: "Sends a notification to your phone when price momentum is moving unusually fast and Surge Protector is watching the move.",
                    tint: WealthTheme.cyan,
                    isOn: $protection.speedAlertEnabled
                )

                wealthSystemToggleCard(
                    title: "BRAIN CAPITAL ALERT",
                    subtitle: "Sends a notification to your phone if the brain finds a strong buy but there is not enough capital available.",
                    tint: WealthTheme.cyan,
                    isOn: $protection.capitalAlertEnabled
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("ACCOUNT RESET")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("Resets capital, portfolio, queue, reserves, and profit totals back to zero for a clean AI test run.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(cardShell(cornerRadius: 18))

                Button {
                    WealthPortfolioStore.shared.resetAccountToZero()
                } label: {
                    Text("RESET TO ZERO")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(WealthTheme.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.cyan, secondaryTint: WealthTheme.green))
    }
}
