import Foundation

extension WealthPortfolioStore {
    private enum GoalWindowKind {
        case daily
        case compound
        case mission

        var baselineKey: String {
            switch self {
            case .daily:
                return "awc_goal_daily_baseline_pnl"
            case .compound:
                return "awc_goal_compound_baseline_pnl"
            case .mission:
                return "awc_goal_mission_baseline_pnl"
            }
        }

        var startDateKey: String {
            switch self {
            case .daily:
                return "awc_goal_daily_start_date"
            case .compound:
                return "awc_goal_compound_start_date"
            case .mission:
                return "awc_goal_mission_start_date"
            }
        }

        var totalModeKey: String {
            switch self {
            case .daily:
                return "awc_goal_daily_total_mode"
            case .compound:
                return "awc_goal_compound_total_mode"
            case .mission:
                return "awc_goal_mission_total_mode"
            }
        }
    }

    private enum CampaignStorageKey {
        static let compoundWeeks = "awc_campaign_weeks"
        static let missionWeeks = "awc_mission_weeks"
    }

    var dailyGoalActual: Double {
        goalWindowActual(for: .daily, weeks: 0)
    }

    var compoundGoalActual: Double {
        let weeks = max(1, UserDefaults.standard.object(forKey: CampaignStorageKey.compoundWeeks) as? Int ?? 4)
        return goalWindowActual(for: .compound, weeks: weeks)
    }

    var missionGoalActual: Double {
        let weeks = max(1, UserDefaults.standard.object(forKey: CampaignStorageKey.missionWeeks) as? Int ?? 52)
        return goalWindowActual(for: .mission, weeks: weeks)
    }

    private func goalWindowActual(for kind: GoalWindowKind, weeks: Int, now: Date = .now) -> Double {
        let defaults = UserDefaults.standard
        let calendar = Calendar.autoupdatingCurrent
        let currentPnL = totalPnL

        switch kind {
        case .daily:
            return dailyWindowActual(defaults: defaults, calendar: calendar, currentPnL: currentPnL, now: now)
        case .compound, .mission:
            return rollingCampaignActual(for: kind, weeks: weeks, defaults: defaults, currentPnL: currentPnL, now: now)
        }
    }

    private func dailyWindowActual(
        defaults: UserDefaults,
        calendar: Calendar,
        currentPnL: Double,
        now: Date
    ) -> Double {
        let baselineKey = GoalWindowKind.daily.baselineKey
        let startDateKey = GoalWindowKind.daily.startDateKey
        let startOfToday = calendar.startOfDay(for: now)

        if let storedStartDate = defaults.object(forKey: startDateKey) as? Date,
           let baseline = defaults.object(forKey: baselineKey) as? Double,
           calendar.isDate(storedStartDate, inSameDayAs: now) {
            return currentPnL - baseline
        }

        defaults.set(startOfToday, forKey: startDateKey)
        defaults.set(currentPnL, forKey: baselineKey)
        return 0
    }

    private func rollingCampaignActual(
        for kind: GoalWindowKind,
        weeks: Int,
        defaults: UserDefaults,
        currentPnL: Double,
        now: Date
    ) -> Double {
        let startDateKey = kind.startDateKey
        let baselineKey = kind.baselineKey
        let totalModeKey = kind.totalModeKey
        let cycleDuration = TimeInterval(weeks) * 7 * 24 * 60 * 60

        let storedStartDate = defaults.object(forKey: startDateKey) as? Date
        let storedBaseline = defaults.object(forKey: baselineKey) as? Double ?? 0
        let totalModeEnabled = defaults.bool(forKey: totalModeKey)

        guard let storedStartDate else {
            defaults.set(now, forKey: startDateKey)
            defaults.set(0.0, forKey: baselineKey)
            defaults.set(true, forKey: totalModeKey)
            return currentPnL
        }

        if now.timeIntervalSince(storedStartDate) >= cycleDuration {
            defaults.set(now, forKey: startDateKey)
            defaults.set(currentPnL, forKey: baselineKey)
            defaults.set(true, forKey: totalModeKey)
            return 0
        }

        if !totalModeEnabled {
            defaults.set(0.0, forKey: baselineKey)
            defaults.set(true, forKey: totalModeKey)
            return currentPnL
        }

        return currentPnL - storedBaseline
    }
}
