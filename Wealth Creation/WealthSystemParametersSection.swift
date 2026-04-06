import SwiftUI

struct WealthSystemParametersSection: View {
    enum ProtectionTab: String, CaseIterable, Identifiable {
        case shield = "Shield"
        case profit = "Profit"
        case floor = "Floor"
        var id: String { rawValue }
    }

    let hasDesktopSystemLayout: Bool

    @ObservedObject var protection = WealthProtectionSettingsStore.shared
    @ObservedObject var notifications = WealthNotificationStore.shared
    @ObservedObject var portfolio = WealthPortfolioStore.shared
    @ObservedObject private var engine = WealthEngineStore.shared

    @State var protectionTab: ProtectionTab = .shield
    @State private var demoTopUpAmount: Double = 0

    @AppStorage("awc_scan_refresh_light_minutes") var lightRefreshMinutes: Double = 10
    @AppStorage("awc_scan_refresh_heavy_minutes") var heavyRefreshMinutes: Double = 30

    var body: some View {
        VStack(spacing: 12) {
            if hasDesktopSystemLayout {
                desktopParametersLeadCard
            }

            if !hasDesktopSystemLayout {
                WealthSystemAIStatusPanel(
                    activationCycleComplete: engine.activationCycleComplete,
                    activationStage: engine.activationStage,
                    activationStageTotal: engine.activationStageTotal,
                    lightRefreshMinutes: Int(lightRefreshMinutes),
                    heavyRefreshMinutes: Int(heavyRefreshMinutes)
                )
            }

            wealthSystemToggleCard(title: "KILL SWITCH", subtitle: "Instant emergency stop for new trading activity.", tint: WealthTheme.red, isOn: $protection.killSwitch)
            protectionControlsCard
            baseCurrencyCard
            demoCapitalCard

            if hasDesktopSystemLayout {
                desktopRefreshAndAlertsSection
            }
        }
    }

    private var protectionControlsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROTECTION CONTROLS")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)

            segmentBar(options: ProtectionTab.allCases.map(\.rawValue), selected: protectionTab.rawValue, activeColor: .white, darkWhenSelected: true) {
                protectionTab = ProtectionTab(rawValue: $0) ?? .shield
            }

            protectionPanel
            surgeProtectorCard
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.red, secondaryTint: WealthTheme.purple))
    }

    private var surgeProtectorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SURGE PROTECTOR")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("If a share hits the + sell target while rising quickly, the brain delays the sell and waits for the extra rise amount below.")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                Toggle("", isOn: $protection.surgeEnabled)
                    .tint(WealthTheme.orange)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("MANUAL SURGE OVERRIDE")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                percentField(value: $protection.surgeOverridePercent, tint: WealthTheme.orange)
            }
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 22, tint: WealthTheme.orange, secondaryTint: WealthTheme.cyan))
    }

    private var baseCurrencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BASE CURRENCY")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(.white)
            segmentBar(options: ["AUD", "USD", "EUR"], selected: protection.baseCurrency, activeColor: .white, darkWhenSelected: true) {
                protection.baseCurrency = $0
            }
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.white.opacity(0.85), secondaryTint: WealthTheme.cyan))
    }

    private var demoCapitalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DEMO CAPITAL")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Turn demo mode on for test capital, then switch it off when you go live.")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WealthTheme.grey)
                }
                Spacer()
                Toggle("", isOn: $protection.demoMode)
                    .tint(WealthTheme.green)
                    .labelsHidden()
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TRANSFER AMOUNT")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                    moneyField(value: $demoTopUpAmount, tint: WealthTheme.green)
                }

                Button {
                    portfolio.addDemoCredits(demoTopUpAmount)
                    demoTopUpAmount = 0
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .black))
                        Text("TRANSFER CAPITAL")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [WealthTheme.green, WealthTheme.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(glowPanelShell(cornerRadius: 24, tint: WealthTheme.green, secondaryTint: WealthTheme.cyan))
    }
}
