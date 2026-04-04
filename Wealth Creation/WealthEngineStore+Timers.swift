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
        softTimer?.invalidate()
        softTimer = nil
        heavyTimer?.invalidate()
        heavyTimer = nil
    }

    // MARK: - Private scheduling

    private func scheduleRecurringTimers() {
        // IBKR price-only timers (9 m, 19 m, 29 m)
        scheduleIBKRTimer(at: TimerInterval.ibkr1)
        scheduleIBKRTimer(at: TimerInterval.ibkr2)
        scheduleIBKRTimer(at: TimerInterval.ibkr3)

        // Soft refresh timers (10 m, 20 m)
        scheduleSoftTimer(at: TimerInterval.soft1)
        scheduleSoftTimer(at: TimerInterval.soft2)

        // Deep refresh timer (30 m)
        scheduleDeepTimer(at: TimerInterval.deep)
    }

    private func scheduleIBKRTimer(at interval: TimeInterval) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.refresh(mode: .ibkr)
            }
        }
    }

    private func scheduleSoftTimer(at interval: TimeInterval) {
        // Keep a reference to the last created soft timer so it can be
        // invalidated via `invalidateTimers()`.
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.refresh(mode: .soft)
            }
        }
        softTimer = timer
    }

    private func scheduleDeepTimer(at interval: TimeInterval) {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.refresh(mode: .deep)
            }
        }
        heavyTimer = timer
    }
}
