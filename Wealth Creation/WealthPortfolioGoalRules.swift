import Foundation

extension WealthPortfolioStore {
    private enum GoalWindowKind {
        case daily
        case compound
        case mission

        var baselineKey: String {
            switch self {
            case .daily:
                return "awc_goal_daily_baseline_profit"
            case .compound:
                return "awc_goal_compound_baseline_profit"
            case .mission:
                return "awc_goal_mission_baseline_profit"
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

        var durationWeeksKey: String? {
            switch self {
            case .daily:
                return nil
            case .compound:
                return "awc_campaign_weeks"
            case .mission:
                return "awc_mission_weeks"
            }
        }
    }

    var dailyGoalActual: Double {
        dailyProfit
    }

    var compoundGoalActual: Double {
        targetHitRollingActual(for: .compound)
    }

    var missionGoalActual: Double {
        targetHitRollingActual(for: .mission)
    }

    private func targetHitRollingActual(for kind: GoalWindowKind, now: Date = .now) -> Double {
        let defaults = UserDefaults.standard
        let baselineKey = kind.baselineKey
        let startDateKey = kind.startDateKey
        let currentProfit = earnedProfit

        guard let storedBaseline = defaults.object(forKey: baselineKey) as? Double else {
            defaults.set(currentProfit, forKey: baselineKey)
            defaults.set(now, forKey: startDateKey)
            return 0
        }

        return currentProfit - storedBaseline
    }

    private func remainingWindowPressure(for kind: GoalWindowKind, now: Date = .now) -> Double {
        guard let durationWeeksKey = kind.durationWeeksKey else { return 0 }

        let defaults = UserDefaults.standard
        let weeks = max(1, defaults.object(forKey: durationWeeksKey) as? Int ?? 1)
        guard let startDate = defaults.object(forKey: kind.startDateKey) as? Date else { return 0 }

        let duration = TimeInterval(weeks) * 7 * 24 * 60 * 60
        guard duration > 0 else { return 0 }

        let elapsed = max(0, now.timeIntervalSince(startDate))
        let remainingRatio = max(0, min(1, 1 - (elapsed / duration)))
        return 1 - remainingRatio
    }

    func compoundRemainingWindowPressure(now: Date = .now) -> Double {
        remainingWindowPressure(for: .compound, now: now)
    }

    func missionRemainingWindowPressure(now: Date = .now) -> Double {
        remainingWindowPressure(for: .mission, now: now)
    }

    func refreshGoalBaselinesIfNeeded(
        dailyTarget: Double,
        compoundTarget: Double,
        missionTarget: Double,
        now: Date = .now
    ) {
        let defaults = UserDefaults.standard
        let calendar = Calendar.autoupdatingCurrent

        let dailyStartKey = GoalWindowKind.daily.startDateKey
        let dailyBaselineKey = GoalWindowKind.daily.baselineKey
        let startOfToday = calendar.startOfDay(for: now)

        if let storedDailyStart = defaults.object(forKey: dailyStartKey) as? Date {
            if !calendar.isDate(storedDailyStart, inSameDayAs: now) {
                defaults.set(startOfToday, forKey: dailyStartKey)
                defaults.set(dailyProfit, forKey: dailyBaselineKey)
            }
        } else {
            defaults.set(startOfToday, forKey: dailyStartKey)
            defaults.set(dailyProfit, forKey: dailyBaselineKey)
        }
    }

    func resetGoalProgressBaselines() {
        let defaults = UserDefaults.standard
        let kinds: [GoalWindowKind] = [.daily, .compound, .mission]

        for kind in kinds {
            defaults.removeObject(forKey: kind.baselineKey)
            defaults.removeObject(forKey: kind.startDateKey)
        }
    }
}
