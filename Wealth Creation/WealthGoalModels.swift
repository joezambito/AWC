struct GoalProgress {
    let target: Double
    let actual: Double

    var remaining: Double {
        max(0, target - actual)
    }

    var varianceFromTarget: Double {
        actual - target
    }

    var percent: Double {
        guard target > 0 else { return 0 }
        return min(1, max(0, actual / target))
    }

    var shortfallRatio: Double {
        guard target > 0 else { return 0 }
        return max(0, remaining / target)
    }

    var belowZeroPenalty: Double {
        guard actual < 0, target > 0 else { return 0 }
        let ratio = abs(actual) / target
        return min(0.22, 0.08 + (ratio * 0.12))
    }

    var pressure: Double {
        min(1, shortfallRatio + belowZeroPenalty)
    }

    var isBehind: Bool {
        remaining > 0
    }

    var isNegative: Bool {
        actual < 0
    }
}

struct WealthGoalVector {
    let daily: GoalProgress
    let compound: GoalProgress
    let mission: GoalProgress

    var dailyPressure: Double { daily.pressure }
    var compoundPressure: Double { compound.pressure }
    var missionPressure: Double { mission.pressure }

    var weightedPressure: Double {
        let base = (dailyPressure * 0.55) + (compoundPressure * 0.30) + (missionPressure * 0.15)
        let belowZeroBoost = [daily, compound, mission].contains(where: \.isNegative) ? 0.08 : 0
        return min(1, max(0, base + belowZeroBoost))
    }

    var tradingPressure: Double {
        min(0.55, max(0, (weightedPressure * 0.55) + negativeTargetBoost))
    }

    var negativeTargetBoost: Double {
        let negativeCount = [daily, compound, mission].filter(\.isNegative).count
        switch negativeCount {
        case 3: return 0.10
        case 2: return 0.07
        case 1: return 0.04
        default: return 0
        }
    }

    var dominantTarget: String {
        let pressures = [
            ("DAILY", dailyPressure),
            ("COMPOUND", compoundPressure),
            ("MISSION", missionPressure)
        ]

        return pressures
            .max { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0 > rhs.0
                }
                return lhs.1 < rhs.1
            }?.0 ?? "DAILY"
    }

    func progress(for target: String) -> GoalProgress {
        switch target {
        case "COMPOUND": return compound
        case "MISSION": return mission
        default: return daily
        }
    }

    func pressure(for target: String) -> Double {
        switch target {
        case "COMPOUND": return compoundPressure
        case "MISSION": return missionPressure
        default: return dailyPressure
        }
    }
}
