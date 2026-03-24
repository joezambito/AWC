import SwiftUI

extension CampaignView {
    var phoneBody: some View {
        VStack(spacing: 8) {
            segmentBar(
                options: GoalTab.allCases.map(\.rawValue),
                selected: selectedTab.rawValue,
                activeColor: tabAccent(selectedTab)
            ) { value in
                selectedTab = GoalTab(rawValue: value) ?? .daily
            }

            currentGoalCard
        }
    }

    func desktopBody(isWide: Bool) -> some View {
        VStack(spacing: 10) {
            sectionShell(title: "CAMPAIGN", subtitle: "Daily, compound and mission targets")

            segmentBar(
                options: GoalTab.allCases.map(\.rawValue),
                selected: selectedTab.rawValue,
                activeColor: tabAccent(selectedTab)
            ) { value in
                selectedTab = GoalTab(rawValue: value) ?? .daily
            }

            if isWide {
                HStack(alignment: .top, spacing: 12) {
                    currentGoalCard
                    desktopRail
                        .frame(maxWidth: 300)
                }
            } else {
                currentGoalCard
                desktopRail
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    var currentGoalCard: some View {
        switch selectedTab {
        case .daily:
            return AnyView(
                GoalCard(
                    title: "DAILY TARGET",
                    subtitle: "SHORT-TERM PROFIT GOAL",
                    targetTitle: "TARGET AMOUNT",
                    targetValue: $dailyTarget,
                    timeframeTitle: nil,
                    timeframeValue: nil,
                    valueTitle: "TODAY'S PROFIT",
                    value: dailyProgress.actual,
                    remaining: dailyProgress.remaining,
                    accent: WealthTheme.green
                )
            )
        case .compound:
            return AnyView(
                GoalCard(
                    title: "COMPOUND TARGET",
                    subtitle: "MID-TERM PROFIT GOAL",
                    targetTitle: "CAMPAIGN TARGET",
                    targetValue: $compoundTarget,
                    timeframeTitle: "COMPOUND TIMEFRAME (WEEKS)",
                    timeframeValue: $compoundWeeks,
                    valueTitle: "CAMPAIGN PROFIT",
                    value: compoundProgress.actual,
                    remaining: compoundProgress.remaining,
                    accent: WealthTheme.cyan
                )
            )
        case .mission:
            return AnyView(
                GoalCard(
                    title: "MISSION TARGET",
                    subtitle: "BIG-PICTURE PROFIT GOAL",
                    targetTitle: "MISSION TARGET",
                    targetValue: $missionTarget,
                    timeframeTitle: "MISSION TIMEFRAME (WEEKS)",
                    timeframeValue: $missionWeeks,
                    valueTitle: "MISSION PROFIT",
                    value: missionProgress.actual,
                    remaining: missionProgress.remaining,
                    accent: WealthTheme.purple
                )
            )
        }
    }

    var desktopRail: some View {
        VStack(spacing: 12) {
            progressPulse(title: "DAILY", progress: dailyProgress)
            progressPulse(title: "COMPOUND", progress: compoundProgress)
            progressPulse(title: "MISSION", progress: missionProgress)

            desktopGoalPulse(
                title: engine.brainSnapshot.capitalDiscipline,
                value: engine.brainSnapshot.targetDriver,
                subtitle: engine.brainSnapshot.targetPressure,
                tint: engine.brainSnapshot.mode.color
            )
        }
    }

    func progressPulse(title: String, progress: GoalProgress) -> some View {
        desktopGoalPulse(
            title: title,
            value: "\(Int(progress.percent * 100))%",
            subtitle: remainingText(progress.remaining),
            tint: wealthPnLTint(progress.varianceFromTarget == 0 ? progress.actual : progress.varianceFromTarget)
        )
    }

    func remainingText(_ remaining: Double) -> String {
        if remaining > 0 {
            return "Remaining \(WealthFormat.money(remaining))"
        }
        return "On target"
    }

    func tabAccent(_ tab: GoalTab) -> Color {
        switch tab {
        case .daily:
            return WealthTheme.green
        case .compound:
            return WealthTheme.cyan
        case .mission:
            return WealthTheme.purple
        }
    }
}
