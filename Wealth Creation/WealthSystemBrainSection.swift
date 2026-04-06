import SwiftUI

struct WealthSystemBrainSection: View {
    let hasDesktopSystemLayout: Bool

    @ObservedObject private var engine = WealthEngineStore.shared
    @ObservedObject private var brainStore = WealthBrainStore.shared
    @AppStorage("awc_scan_refresh_light_minutes") private var lightRefreshMinutes: Double = 10
    @AppStorage("awc_scan_refresh_heavy_minutes") private var heavyRefreshMinutes: Double = 30

    var body: some View {
        VStack(spacing: 12) {
            if hasDesktopSystemLayout {
                wealthSystemHeroPanel(
                    title: "BRAIN",
                    subtitle: "Operator view, provider stack and tuning",
                    icon: "brain.head.profile",
                    badge: brainStore.modelState.modelVersion,
                    badgeColor: WealthTheme.purple
                )
            }

            WealthSystemBrainOverviewPanel(
                summary: engine.brainSnapshot.summary,
                modeLabel: engine.brainSnapshot.mode.rawValue,
                modeTint: engine.brainSnapshot.mode.color,
                pressure: engine.brainSnapshot.targetPressure,
                driver: engine.brainSnapshot.targetDriver.uppercased(),
                sizing: engine.brainSnapshot.capitalDiscipline,
                top: engine.brainSnapshot.hottestSymbol,
                action: engine.brainSnapshot.hottestDecision,
                command: engine.brainSnapshot.hottestCommand,
                trust: engine.brainSnapshot.trustSignal,
                rotate: engine.brainSnapshot.rotationSignal,
                trend: engine.brainSnapshot.trendSignal,
                momentum: engine.brainSnapshot.momentumSignal,
                pattern: engine.brainSnapshot.patternSignal,
                smart: engine.brainSnapshot.smartMoneySignal,
                event: engine.brainSnapshot.eventSignal,
                anomaly: engine.brainSnapshot.anomalySignal,
                modelReadiness: brainStore.modelState.readiness,
                computeMode: brainStore.modelState.computeMode,
                dataReadiness: brainStore.modelState.dataReadiness,
                runtimeCoverageText: WealthBrainToggleStore.shared.runtimeCoverageText,
                learningSummary: brainStore.lastLearningSummary
            )

            if hasDesktopSystemLayout {
                WealthSystemDesktopBrainPanel(
                    modelState: brainStore.modelState,
                    learningSummary: brainStore.lastLearningSummary,
                    featureSnapshots: Array(brainStore.featureSnapshots.prefix(3))
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
            WealthSystemBrainTuningPanel()
            WealthAdvancedAIStackPanel()
            WealthSystemAIRefreshPanel(
                hasDesktopSystemLayout: hasDesktopSystemLayout,
                lightRefreshMinutes: $lightRefreshMinutes,
                heavyRefreshMinutes: $heavyRefreshMinutes
            )
        }
    }
}
