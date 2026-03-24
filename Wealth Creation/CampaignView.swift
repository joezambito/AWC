import SwiftUI

struct CampaignView: View {
    enum GoalTab: String, CaseIterable, Identifiable {
        case daily = "Daily Target"
        case compound = "Compound"
        case mission = "Mission"

        var id: String { rawValue }
    }

    enum StorageKey {
        static let dailyTarget = "awc_daily_target"
        static let compoundTarget = "awc_campaign_target"
        static let missionTarget = "awc_mission_amount"
        static let compoundWeeks = "awc_campaign_weeks"
        static let missionWeeks = "awc_mission_weeks"
    }

    @ObservedObject var portfolio = WealthPortfolioStore.shared
    @ObservedObject var engine = WealthEngineStore.shared

    @State var selectedTab: GoalTab = .daily

    @AppStorage(StorageKey.dailyTarget) var dailyTarget: Double = 100
    @AppStorage(StorageKey.compoundTarget) var compoundTarget: Double = 1_000
    @AppStorage(StorageKey.missionTarget) var missionTarget: Double = 25_000
    @AppStorage(StorageKey.compoundWeeks) var compoundWeeks: Int = 4
    @AppStorage(StorageKey.missionWeeks) var missionWeeks: Int = 52

    var hasDesktopLayout: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }

    var dailyProgress: GoalProgress {
        portfolio.dailyGoal(target: dailyTarget)
    }

    var compoundProgress: GoalProgress {
        portfolio.compoundGoal(target: compoundTarget)
    }

    var missionProgress: GoalProgress {
        portfolio.missionGoal(target: missionTarget)
    }

    var body: some View {
        VStack(spacing: hasDesktopLayout ? 10 : 8) {
            if hasDesktopLayout {
                GeometryReader { proxy in
                    desktopBody(isWide: proxy.size.width >= 920)
                }
                .frame(maxWidth: .infinity, minHeight: 740, alignment: .top)
            } else {
                phoneBody
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
