import Foundation

extension WealthEngineStore {
    private var minimumRecurringLeadTime: TimeInterval { 90 }
    private var phoneStartupScanDelayNanoseconds: UInt64 { 5_000_000_000 }
    private var phoneStartupFinalizeDelayNanoseconds: UInt64 { 2_000_000_000 }

    var prefersFullSpeedActivation: Bool {
#if targetEnvironment(macCatalyst)
        return true
#else
        return false
#endif
    }

    func runActivationSequence() {
        softTimer?.invalidate()
        heavyTimer?.invalidate()
        softTimer = nil
        heavyTimer = nil

        activationTask?.cancel()
        activationTask = Task { @MainActor [weak self] in
            let steps: [(UInt64, RefreshMode, Bool)] = [
                (0, .startup, false),
                (self?.phoneStartupScanDelayNanoseconds ?? 5_000_000_000, .deep, false)
            ]

            for (delay, mode, publishToUI) in steps {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                self?.refresh(mode: mode, publishToUI: publishToUI)
            }

            try? await Task.sleep(nanoseconds: self?.phoneStartupFinalizeDelayNanoseconds ?? 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.applyPendingRefreshState()
            self?.rescheduleTimers()
            self?.activationTask = nil
        }
    }

    func prepareForFreshLaunch() {
        softTimer?.invalidate()
        heavyTimer?.invalidate()
        softTimer = nil
        heavyTimer = nil
        activationTask?.cancel()
        activationTask = nil
        hasBootstrapped = false
        pendingRefreshPayload = nil
        pendingPublishTask?.cancel()
        pendingPublishTask = nil
        activationStageTotal = prefersFullSpeedActivation ? 1 : Self.phoneActivationStageCount
        activationStage = 0
        activationCycleComplete = lastRefresh != nil
        tradingLifecycleArmed = false
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        catchUpRecurringCyclesIfNeeded()

        if prefersFullSpeedActivation {
            activationStageTotal = 1
            activationStage = activationStageTotal
            activationCycleComplete = false
            tradingLifecycleArmed = false
            refresh(mode: .deep)
            rescheduleTimers()
            return
        }

        activationStageTotal = Self.phoneActivationStageCount
        activationStage = 0
        activationCycleComplete = false
        tradingLifecycleArmed = false
        runActivationSequence()
    }

    func handleForegroundActivation() {
        catchUpRecurringCyclesIfNeeded()
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < 8 {
            return
        }

        if prefersFullSpeedActivation {
            activationStageTotal = 1
            activationStage = activationStageTotal
            activationCycleComplete = false
            tradingLifecycleArmed = false
            refresh(mode: .deep)
            return
        }

        activationStageTotal = Self.phoneActivationStageCount
        activationStage = 0
        activationCycleComplete = false
        tradingLifecycleArmed = false
        runActivationSequence()
    }

    func rescheduleTimers() {
        softTimer?.invalidate()
        heavyTimer?.invalidate()

        let softMinutes = configuredSoftRefreshMinutes
        let heavyMinutes = configuredHeavyRefreshMinutes

        softTimer = alignedRepeatingTimer(minutes: softMinutes) { [weak self] in
            self?.refresh(mode: .soft, countsTowardDailyCycles: true)
        }

        heavyTimer = alignedRepeatingTimer(minutes: heavyMinutes) { [weak self] in
            self?.refresh(mode: .heavy, countsTowardDailyCycles: true)
        }
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
}
