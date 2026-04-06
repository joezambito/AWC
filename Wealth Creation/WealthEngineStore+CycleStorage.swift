import Foundation

extension WealthEngineStore {
    @discardableResult
    func handleDayRolloverIfNeeded(now: Date = .now) -> Bool {
        let didRollOver = resetDailyCycleCountIfNeeded(now: now)
        WealthEventLogStore.shared.prune(now: now)

        guard didRollOver else { return false }

        lastRecurringCycleLabel = "WAITING"
        defaults.set("WAITING", forKey: StorageKey.lastRecurringCycleLabel)
        defaults.set("WAITING", forKey: LegacyStorageKey.lastRecurringCycleLabel)
        return true
    }

    @discardableResult
    func resetDailyCycleCountIfNeeded(now: Date = .now) -> Bool {
        let dayKey = Self.dayStamp(for: now)
        let storedDay = defaults.string(forKey: StorageKey.dailyScanCycleDay)
            ?? defaults.string(forKey: LegacyStorageKey.dailyScanCycleDay)
        guard storedDay != dayKey else { return false }

        dailySoftCycleCount = 0
        dailyHeavyCycleCount = 0
        defaults.set(0, forKey: StorageKey.dailySoftCycleCount)
        defaults.set(0, forKey: StorageKey.dailyHeavyCycleCount)
        defaults.set(dayKey, forKey: StorageKey.dailyScanCycleDay)
        defaults.set(0, forKey: LegacyStorageKey.dailySoftCycleCount)
        defaults.set(0, forKey: LegacyStorageKey.dailyHeavyCycleCount)
        defaults.set(dayKey, forKey: LegacyStorageKey.dailyScanCycleDay)
        return true
    }

    func normalizeRecurringCycleStorageIfNeeded() {
        let currentVersion = 1
        let storedVersion = defaults.integer(forKey: StorageKey.recurringCycleCounterVersion)
        guard storedVersion < currentVersion else { return }

        let softCount = defaults.object(forKey: StorageKey.dailySoftCycleCount) != nil
            ? defaults.integer(forKey: StorageKey.dailySoftCycleCount)
            : defaults.integer(forKey: LegacyStorageKey.dailySoftCycleCount)
        let heavyCount = defaults.object(forKey: StorageKey.dailyHeavyCycleCount) != nil
            ? defaults.integer(forKey: StorageKey.dailyHeavyCycleCount)
            : defaults.integer(forKey: LegacyStorageKey.dailyHeavyCycleCount)
        let storedDay = defaults.string(forKey: StorageKey.dailyScanCycleDay)
            ?? defaults.string(forKey: LegacyStorageKey.dailyScanCycleDay)
            ?? Self.dayStamp(for: .now)
        let cycleLabel = defaults.string(forKey: StorageKey.lastRecurringCycleLabel)
            ?? defaults.string(forKey: LegacyStorageKey.lastRecurringCycleLabel)
            ?? "WAITING"

        dailySoftCycleCount = softCount
        dailyHeavyCycleCount = heavyCount
        defaults.set(softCount, forKey: StorageKey.dailySoftCycleCount)
        defaults.set(heavyCount, forKey: StorageKey.dailyHeavyCycleCount)
        defaults.set(storedDay, forKey: StorageKey.dailyScanCycleDay)
        defaults.set(cycleLabel, forKey: StorageKey.lastRecurringCycleLabel)
        defaults.set(currentVersion, forKey: StorageKey.recurringCycleCounterVersion)
    }

    func resolvedRecurringCycleLabel() -> String {
        defaults.string(forKey: StorageKey.lastRecurringCycleLabel)
            ?? defaults.string(forKey: LegacyStorageKey.lastRecurringCycleLabel)
            ?? "WAITING"
    }

    func resolvedDailySoftCycleCount() -> Int {
        if defaults.object(forKey: StorageKey.dailySoftCycleCount) != nil {
            return defaults.integer(forKey: StorageKey.dailySoftCycleCount)
        }
        return defaults.integer(forKey: LegacyStorageKey.dailySoftCycleCount)
    }

    func resolvedDailyHeavyCycleCount() -> Int {
        if defaults.object(forKey: StorageKey.dailyHeavyCycleCount) != nil {
            return defaults.integer(forKey: StorageKey.dailyHeavyCycleCount)
        }
        return defaults.integer(forKey: LegacyStorageKey.dailyHeavyCycleCount)
    }

    static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func schedulePendingRefreshPublish(
        payload: PendingRefreshPayload,
        after delayNanoseconds: UInt64 = 2_000_000_000
    ) {
        pendingPublishTask?.cancel()
        pendingPublishTask = Task { @MainActor [self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            await applyPendingRefreshState(payload)
        }
    }
}
