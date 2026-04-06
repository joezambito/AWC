import Foundation

extension WealthEngineStore {
    private enum ScanCounterStorageKey {
        static let lastRecurringCycleLabel = "awc_last_recurring_cycle_label"
        static let dailySoftCycleCount = "awc_daily_soft_cycle_count"
        static let dailyHeavyCycleCount = "awc_daily_heavy_cycle_count"
        static let lastSoftCycleAt = "awc_last_soft_cycle_at"
        static let lastHardCycleAt = "awc_last_hard_cycle_at"
    }

    enum RecurringCycleKind: String {
        case soft = "SOFT"
        case hard = "HARD"
    }

    var dailyHardCycleCountLabel: String {
        "HARD \(dailyHeavyCycleCount)"
    }

    func recordRecurringCycle(_ kind: RecurringCycleKind, now: Date = .now) {
        resetDailyCycleCountIfNeeded(now: now)

        switch kind {
        case .soft:
            dailySoftCycleCount += 1
            defaults.set(dailySoftCycleCount, forKey: ScanCounterStorageKey.dailySoftCycleCount)
            defaults.set(dailySoftCycleCount, forKey: StorageKey.dailySoftCycleCount)
        case .hard:
            dailyHeavyCycleCount += 1
            defaults.set(dailyHeavyCycleCount, forKey: ScanCounterStorageKey.dailyHeavyCycleCount)
            defaults.set(dailyHeavyCycleCount, forKey: StorageKey.dailyHeavyCycleCount)
        }

        lastRecurringCycleLabel = kind.rawValue
        defaults.set(kind.rawValue, forKey: ScanCounterStorageKey.lastRecurringCycleLabel)
        defaults.set(kind.rawValue, forKey: StorageKey.lastRecurringCycleLabel)
        defaults.set(now.timeIntervalSince1970, forKey: timestampKey(for: kind))
    }

    func recurringCycleKind(for mode: RefreshMode) -> RecurringCycleKind? {
        switch mode {
        case .soft:
            return .soft
        case .heavy, .deep:
            return .hard
        case .startup, .quick:
            return nil
        }
    }

    func catchUpRecurringCyclesIfNeeded(now: Date = .now) {
        resetDailyCycleCountIfNeeded(now: now)
    }

    private func applyCatchUpCounters(soft: Int, hard: Int, now: Date) {
        resetDailyCycleCountIfNeeded(now: now)

        if hard > 0 {
            dailyHeavyCycleCount += hard
            defaults.set(dailyHeavyCycleCount, forKey: ScanCounterStorageKey.dailyHeavyCycleCount)
            defaults.set(dailyHeavyCycleCount, forKey: StorageKey.dailyHeavyCycleCount)
            defaults.set(now.timeIntervalSince1970, forKey: timestampKey(for: .hard))
        }

        if soft > 0 {
            dailySoftCycleCount += soft
            defaults.set(dailySoftCycleCount, forKey: ScanCounterStorageKey.dailySoftCycleCount)
            defaults.set(dailySoftCycleCount, forKey: StorageKey.dailySoftCycleCount)
            defaults.set(now.timeIntervalSince1970, forKey: timestampKey(for: .soft))
        }

        if hard > 0 {
            lastRecurringCycleLabel = RecurringCycleKind.hard.rawValue
        } else if soft > 0 {
            lastRecurringCycleLabel = RecurringCycleKind.soft.rawValue
        }
        defaults.set(lastRecurringCycleLabel, forKey: ScanCounterStorageKey.lastRecurringCycleLabel)
        defaults.set(lastRecurringCycleLabel, forKey: StorageKey.lastRecurringCycleLabel)
    }

    private func missedCycleCount(for kind: RecurringCycleKind, intervalMinutes: Double, now: Date) -> Int {
        let interval = max(60, intervalMinutes * 60)
        let startOfToday = Calendar.current.startOfDay(for: now)
        let lastCycleAt = defaults.object(forKey: timestampKey(for: kind)) as? Double
        let referenceDate = max(lastCycleAt.map(Date.init(timeIntervalSince1970:)) ?? startOfToday, startOfToday)
        let elapsed = now.timeIntervalSince(referenceDate)
        guard elapsed >= interval else { return 0 }
        return Int(elapsed / interval)
    }

    private func timestampKey(for kind: RecurringCycleKind) -> String {
        switch kind {
        case .soft:
            return ScanCounterStorageKey.lastSoftCycleAt
        case .hard:
            return ScanCounterStorageKey.lastHardCycleAt
        }
    }
}
