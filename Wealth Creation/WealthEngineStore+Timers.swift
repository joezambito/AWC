import Foundation

// MARK: - WealthEngineStore+Timers
//
// Manages six recurring timers that fire after the startup sequence completes.
//
//   9  min  – IBKR  : update live prices only
//   10 min  – Soft  : light refresh (universe, AI, market)
//   19 min  – IBKR  : update live prices only
//   20 min  – Soft  : light refresh (universe, AI, market)
//   29 min  – IBKR  : update live prices only
//   30 min  – Deep  : heavy refresh (everything)
//
// All timer callbacks dispatch work to a background thread so the main
// thread / UI is never blocked.
//
// `invalidateTimers()` is the single teardown entry-point for ALL timer
// types – softTimer, heavyTimer, scheduledCheckpointTimer,
// preScanBurstTimer, IBKR timers, and extra soft timers.  Always call
// `invalidateTimers()` instead of manually nil-ing each reference.

// MARK: - IBKR and extra soft timer storage
//
// Swift extensions cannot add stored properties, so timer references that
// exceed the existing `softTimer` and `heavyTimer` stored properties are
// kept in this file-private holder.  Since WealthEngineStore is a
// MainActor-isolated singleton, access is always serialised.

private final class WealthTimerHolder {
    /// IBKR price-only timers (9 m, 19 m, 29 m).
    var ibkrTimers: [Timer] = []
    /// Extra soft timers beyond the first (the first is stored in `softTimer`).
    var extraSoftTimers: [Timer] = []
}

private nonisolated(unsafe) let timerHolder = WealthTimerHolder()

extension WealthEngineStore {

    // MARK: Timer intervals (seconds)

    enum TimerInterval {
        static let ibkr1: TimeInterval  =  9 * 60   //  9 min
        static let soft1: TimeInterval  = 10 * 60   // 10 min
        static let ibkr2: TimeInterval  = 19 * 60   // 19 min
        static let soft2: TimeInterval  = 20 * 60   // 20 min
        static let ibkr3: TimeInterval  = 29 * 60   // 29 min
        static let deep:  TimeInterval  = 30 * 60   // 30 min
    }

    // MARK: - Public API

    /// Tear down any existing timers and schedule a fresh set.
    /// Called automatically by `WealthEngineStartupController` once the
    /// startup sequence completes, and again whenever the app is
    /// foregrounded after a prolonged background period.
    func rescheduleTimers() {
        invalidateTimers()
        scheduleRecurringTimers()
    }

    // MARK: - Timer lifecycle (internal helpers)

    func invalidateTimers() {
        // Invalidate and release all IBKR timers
        timerHolder.ibkrTimers.forEach { $0.invalidate() }
        timerHolder.ibkrTimers.removeAll()

        // Invalidate extra soft timers
        timerHolder.extraSoftTimers.forEach { $0.invalidate() }
        timerHolder.extraSoftTimers.removeAll()

        // Invalidate the primary soft and deep timers
        softTimer?.invalidate()
        softTimer = nil
        heavyTimer?.invalidate()
        heavyTimer = nil

        // Invalidate legacy checkpoint and burst timers (defined in WealthCore.swift).
        // Centralising teardown here prevents duplication across call sites and
        // ensures every timer is released in a single pass.
        scheduledCheckpointTimer?.invalidate()
        scheduledCheckpointTimer = nil
        preScanBurstTimer?.invalidate()
        preScanBurstTimer = nil
    }

    // MARK: - Private scheduling

    private func scheduleRecurringTimers() {
        // IBKR price-only timers (9 m, 19 m, 29 m) – retained in holder
        timerHolder.ibkrTimers.append(makeIBKRTimer(at: TimerInterval.ibkr1))
        timerHolder.ibkrTimers.append(makeIBKRTimer(at: TimerInterval.ibkr2))
        timerHolder.ibkrTimers.append(makeIBKRTimer(at: TimerInterval.ibkr3))

        // Soft refresh timers (10 m, 20 m).
        // The first is stored in the existing `softTimer` property; the
        // second is retained in `timerHolder.extraSoftTimers` to prevent
        // the reference from being lost and to enable proper invalidation.
        softTimer = makeSoftTimer(at: TimerInterval.soft1)
        timerHolder.extraSoftTimers.append(makeSoftTimer(at: TimerInterval.soft2))

        // Deep refresh timer (30 m)
        heavyTimer = makeDeepTimer(at: TimerInterval.deep)
    }

    private func makeIBKRTimer(at interval: TimeInterval) -> Timer {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.refresh(mode: .ibkr)
            }
        }
    }

    private func makeSoftTimer(at interval: TimeInterval) -> Timer {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.refresh(mode: .soft)
            }
        }
    }

    private func makeDeepTimer(at interval: TimeInterval) -> Timer {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.refresh(mode: .deep)
            }
        }
    }
}
