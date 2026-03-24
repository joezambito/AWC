import SwiftUI

struct WealthSystemBrainSection: View {
    let hasDesktopSystemLayout: Bool

    @ObservedObject private var engine = WealthEngineStore.shared
    @ObservedObject private var brainStore = WealthBrainStore.shared

    var body: some View {
        VStack(spacing: 12) {
            if hasDesktopSystemLayout {
                wealthSystemHeroPanel(
                    title: "BRAIN",
                    subtitle: "Brain control tab, tuning and operator view",
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

            WealthSystemBrainTuningPanel()
            WealthAdvancedAIStackPanel()
        }
    }
}
