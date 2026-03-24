import SwiftUI

struct WealthSystemAISection: View {
    let hasDesktopSystemLayout: Bool

    @ObservedObject private var engine = WealthEngineStore.shared

    @AppStorage("awc_scan_refresh_light_minutes") private var lightRefreshMinutes: Double = 10
    @AppStorage("awc_scan_refresh_heavy_minutes") private var heavyRefreshMinutes: Double = 30

    var body: some View {
        VStack(spacing: 12) {
            if hasDesktopSystemLayout {
                wealthSystemHeroPanel(
                    title: "BRAIN CENTER",
                    subtitle: "Alerts, providers and update cycle",
                    icon: "brain.head.profile",
                    badge: engine.activationCycleComplete ? "UP TO DATE" : "ONLINE",
                    badgeColor: engine.activationCycleComplete ? WealthTheme.green : WealthTheme.cyan
                )
            }

            WealthSystemAIStatusPanel(
                activationCycleComplete: engine.activationCycleComplete,
                activationStage: engine.activationStage,
                activationStageTotal: engine.activationStageTotal,
                lightRefreshMinutes: Int(lightRefreshMinutes),
                heavyRefreshMinutes: Int(heavyRefreshMinutes)
            )
            WealthSystemAIProviderPanel()
            WealthSystemAIRefreshPanel(
                hasDesktopSystemLayout: hasDesktopSystemLayout,
                lightRefreshMinutes: $lightRefreshMinutes,
                heavyRefreshMinutes: $heavyRefreshMinutes
            )
        }
    }
}
