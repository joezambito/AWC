//
//  WealthEngineScanScheduler+Timers.swift
//  Wealth Creation
//
//  Created by Joe Zambito on 2/4/2026.
//

import Foundation

extension WealthEngineStore {
    private enum ScheduledCheckpoint {
        case ibkrSoft
        case soft
        case ibkrDeep
        case deep
    }

    private var minimumRecurringLeadTime: TimeInterval { 90 }
    private var fixedIBKRBurstDurationNanoseconds: UInt64 { 50_000_000_000 }
    private var backgroundCheckpointGraceMinutes: Int { 3 }

    func rescheduleTimers() {
        guard activationTask == nil else { return }
        scheduledCheckpointTimer?.invalidate()
        softTimer?.invalidate()
        heavyTimer?.invalidate()
        preScanBurstTimer?.invalidate()
        scheduledCheckpointTimer = nil
        softTimer = nil
        heavyTimer = nil
        preScanBurstTimer = nil
        scheduleNextCheckpointTimer()
    }

    private func alignedRepeatingTimer(minutes: Double, action: @escaping @MainActor () -> Void) -> Timer {
        let interval = minutes * 60
        let firstFire = nextAlignedFireDate(minutes: minutes, minimumLeadTime: minimumRecurringLeadTime)
        let timer = Timer(fire: firstFire, interval: interval, repeats: true) { _ in
            Task { @MainActor in
                action()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func nextAlignedFireDate(
        minutes: Double,
        from now: Date = .now,
        minimumLeadTime: TimeInterval = 0
    ) -> Date {
        let calendar = Calendar.current
        let minuteInterval = max(1, Int(minutes.rounded()))
        let minute = calendar.component(.minute, from: now)
        let second = calendar.component(.second, from: now)
        let nanosecond = calendar.component(.nanosecond, from: now)

        let roundedDown = calendar.date(
            bySettingHour: calendar.component(.hour, from: now),
            minute: minute,
            second: 0,
            of: now
        ) ?? now

        let base = second == 0 && nanosecond == 0
            ? roundedDown.addingTimeInterval(TimeInterval(minuteInterval * 60))
            : roundedDown.addingTimeInterval(60)
        let baseMinute = calendar.component(.minute, from: base)
        let remainder = baseMinute % minuteInterval
        let adjustment = remainder == 0 ? 0 : (minuteInterval - remainder)
        let aligned = base.addingTimeInterval(TimeInterval(adjustment * 60))
        let earliestAllowed = now.addingTimeInterval(minimumLeadTime)
        return aligned < earliestAllowed
            ? aligned.addingTimeInterval(TimeInterval(minuteInterval * 60))
            : aligned
    }

    private func scheduleNextCheckpointTimer(from now: Date = .now) {
        let fireDate = nextScheduledCheckpointDate(after: now)
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let checkpointNow = Date()
                self.runScheduledCheckpoint(now: checkpointNow)
                self.scheduleNextCheckpointTimer(from: checkpointNow)
            }
        }
        scheduledCheckpointTimer = timer
        softTimer = timer
        heavyTimer = timer
        preScanBurstTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func nextScheduledCheckpointDate(after now: Date) -> Date {
        let calendar = Calendar.current
        let allowedMinutes = [9, 10, 19, 20, 29, 30]
        let baseMinute = calendar.date(
            bySettingHour: calendar.component(.hour, from: now),
            minute: calendar.component(.minute, from: now),
            second: 0,
            of: now
        ) ?? now
        let start = now == baseMinute ? now.addingTimeInterval(1) : now

        for offset in 0...120 {
            guard let candidate = calendar.date(byAdding: .minute, value: offset, to: baseMinute) else { continue }
            let minute = calendar.component(.minute, from: candidate)
            if allowedMinutes.contains(minute), candidate > start {
                return candidate
            }
        }

        return baseMinute.addingTimeInterval(60)
    }

    private func runScheduledCheckpoint(now: Date = .now) {
        guard let checkpoint = scheduledCheckpoint(for: now) else { return }

#if DEBUG
        if WealthPipelineTraceLogger.isEnabledForDebugOutput {
            print("[ScanSchedule] checkpoint=\(checkpointLabel(for: checkpoint)) at=\(WealthFormat.clock(now))")
        }
#endif

        switch checkpoint {
        case .ibkrSoft:
            runScheduledIBKRCheckpoint(mode: .soft, now: now)
        case .soft:
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refresh(mode: .soft, countsTowardDailyCycles: true)
            }
        case .ibkrDeep:
            runScheduledIBKRCheckpoint(mode: .deep, now: now)
        case .deep:
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refresh(mode: .deep, countsTowardDailyCycles: true)
            }
        }
    }

    private func runScheduledIBKRCheckpoint(mode: RefreshMode, now: Date) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let nextScanDate = now.addingTimeInterval(60)
            let stagedBlueprints = self.stagedBlueprintsForScheduledScan(mode: mode, scheduledAt: nextScanDate)
            guard !stagedBlueprints.isEmpty else { return }
            let access = await WealthSyncStore.shared.ensureScanBrokerAccess(
                reason: "locked ibkr update",
                blueprints: stagedBlueprints
            )
            guard access == .startedBurst else { return }
            WealthSyncStore.shared.scheduleScanBrokerBurstStop(after: self.fixedIBKRBurstDurationNanoseconds)
        }
    }

    private func stagedBlueprintsForScheduledScan(
        mode: RefreshMode,
        scheduledAt: Date
    ) -> [OpportunityBlueprint] {
        let context = refreshContext(at: scheduledAt)
        return WealthEngineRefreshStaging.stagedBlueprints(
            mode: mode,
            seededBlueprints: Self.seededBlueprints(),
            scannedMarkets: context.scannedMarkets,
            protectedKeys: context.protectedKeys
        )
    }

    private func scheduledCheckpoint(for now: Date) -> ScheduledCheckpoint? {
        let minute = Calendar.current.component(.minute, from: now)
        switch minute {
        case 9, 19:
            return .ibkrSoft
        case 10, 20:
            return .soft
        case 29:
            return .ibkrDeep
        case 30:
            return .deep
        default:
            return nil
        }
    }

    private func checkpointLabel(for checkpoint: ScheduledCheckpoint) -> String {
        switch checkpoint {
        case .ibkrSoft:
            return "IBKR_SOFT"
        case .soft:
            return "AI_SOFT"
        case .ibkrDeep:
            return "IBKR_DEEP"
        case .deep:
            return "AI_DEEP"
        }
    }

    func nextRecurringCheckpointDate(after now: Date = .now) -> Date {
        nextScheduledCheckpointDate(after: now)
    }

    func executeBackgroundScheduledCheckpointIfNeeded(now: Date = .now) async -> Bool {
        let calendar = Calendar.current
        let minuteFloor = calendar.date(
            bySettingHour: calendar.component(.hour, from: now),
            minute: calendar.component(.minute, from: now),
            second: 0,
            of: now
        ) ?? now

        for offset in 0...backgroundCheckpointGraceMinutes {
            guard let candidate = calendar.date(byAdding: .minute, value: -offset, to: minuteFloor) else { continue }
            guard let checkpoint = scheduledCheckpoint(for: candidate) else { continue }

            let stamp = backgroundCheckpointStamp(for: checkpoint, candidate: candidate)
            if defaults.string(forKey: "awc_background_checkpoint_stamp") == stamp {
                continue
            }

            defaults.set(stamp, forKey: "awc_background_checkpoint_stamp")

            switch checkpoint {
            case .ibkrSoft:
                await performBackgroundIBKRCheckpoint(mode: .soft, scheduledAt: candidate)
            case .soft:
                await refreshAsync(mode: .soft, countsTowardDailyCycles: true, publishToUI: false)
            case .ibkrDeep:
                await performBackgroundIBKRCheckpoint(mode: .deep, scheduledAt: candidate)
            case .deep:
                await refreshAsync(mode: .deep, countsTowardDailyCycles: true, publishToUI: false)
            }

            return true
        }

        return false
    }

    private func performBackgroundIBKRCheckpoint(mode: RefreshMode, scheduledAt: Date) async {
        let stagedBlueprints = stagedBlueprintsForScheduledScan(
            mode: mode,
            scheduledAt: scheduledAt.addingTimeInterval(60)
        )
        guard !stagedBlueprints.isEmpty else { return }

        let access = await WealthSyncStore.shared.ensureScanBrokerAccess(
            reason: "background \(refreshModeLabel(mode).lowercased()) ibkr update",
            blueprints: stagedBlueprints
        )
        if access == .startedBurst {
            WealthSyncStore.shared.scheduleScanBrokerBurstStop(after: fixedIBKRBurstDurationNanoseconds)
        }
    }

    private func backgroundCheckpointStamp(for checkpoint: ScheduledCheckpoint, candidate: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm"
        return "\(checkpointLabel(for: checkpoint))-\(formatter.string(from: candidate))"
    }

    private func checkpointProgress(for checkpoint: ScheduledCheckpoint, now: Date) -> Int {
        let minute = Calendar.current.component(.minute, from: now)
        switch minute {
        case 9:
            return 1
        case 10:
            return 2
        case 19:
            return 3
        case 20:
            return 4
        case 29:
            return 5
        case 30:
            return 6
        default:
            switch checkpoint {
            case .ibkrSoft:
                return 1
            case .soft:
                return 2
            case .ibkrDeep:
                return 5
            case .deep:
                return 6
            }
        }
    }
}
