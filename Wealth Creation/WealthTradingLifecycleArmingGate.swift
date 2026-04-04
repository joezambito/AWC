import Foundation

// MARK: - WealthTradingLifecycleArmingGate
//
// Manages the `tradingLifecycleArmed` state transition and ensures
// Activity reconciliation reruns after the gate is armed.
//
// Problem addressed (Issues 4 & 6):
//   Issue 4 – Activity reconciliation may run before `tradingLifecycleArmed`
//             becomes true post-startup, causing timing-dependent admission
//             checks (session open, queue windows) to incorrectly block all
//             downstream cards.
//   Issue 6 – After `tradingLifecycleArmed` becomes true, Activity
//             reconciliation must rerun to promote cards that were blocked
//             during incomplete startup.
//
// Solution (new code only – no existing functions modified):
//   `WealthTradingLifecycleArmingGate` exposes:
//     • `isArmed`                      – authoritative armed/disarmed flag.
//     • `canActivityAdmissionProceed`  – gate predicate for admission checks.
//     • `arm()` / `disarm()`           – state transitions; `arm()` triggers
//       a downstream rebuild via `WealthDownstreamRebuildOrchestrator` so
//       Activity reconciliation reruns the moment the lifecycle becomes ready.
//
//   Call `arm()` from the trading-session controller once the broker
//   session is established and the trading window is confirmed.
//
// Fixes:
//   Issue 4 – Activity admission gate (prevents premature Activity runs)
//   Issue 6 – Post-startup downstream rerun (Activity reruns after arming)

@MainActor
final class WealthTradingLifecycleArmingGate {

    // MARK: Shared instance

    static let shared = WealthTradingLifecycleArmingGate()
    private init() {}

    // MARK: - State

    /// `true` when the trading lifecycle is armed and Activity admission
    /// is permitted to proceed.
    ///
    /// Activity reconciliation MUST NOT complete before this gate is `true`
    /// because timing-dependent admission checks (session open, queue
    /// windows) will incorrectly reject all cards during startup.
    private(set) var isArmed: Bool = false

    // MARK: - Public API

    /// Arm the trading lifecycle gate.
    ///
    /// Idempotent – subsequent calls while already armed are no-ops.
    ///
    /// When the gate transitions from disarmed → armed this method:
    ///   1. Sets `isArmed = true`.
    ///   2. Triggers a downstream rebuild via
    ///      `WealthDownstreamRebuildOrchestrator` so Activity reconciliation
    ///      reruns against the current AI Live results with the correct
    ///      trading-session state (Issue 6 fix).
    ///   3. Posts `wealthTradingLifecycleDidArm`.
    func arm() {
        guard !isArmed else { return }
        isArmed = true

        WealthEventLogStore.shared.record(
            title: "Trading Lifecycle",
            detail: "tradingLifecycleArmed → true; triggering Activity rerun",
            category: "lifecycle",
            tintName: "green",
            timestamp: .now
        )

        // Trigger a downstream rebuild so Activity reconciliation reruns
        // now that the trading lifecycle is armed (Issue 6 fix).
        WealthDownstreamRebuildOrchestrator.shared.triggerRebuild(
            reason: "tradingLifecycleArmed"
        )

        NotificationCenter.default.post(
            name: .wealthTradingLifecycleDidArm,
            object: nil
        )
    }

    /// Disarm the trading lifecycle gate (e.g. on sign-out, session end,
    /// or app background when a fresh broker handshake is required).
    ///
    /// Activity admission will be blocked until `arm()` is called again
    /// so that no stale session timing bleeds into the next live window.
    func disarm() {
        guard isArmed else { return }
        isArmed = false

        WealthEventLogStore.shared.record(
            title: "Trading Lifecycle",
            detail: "tradingLifecycleArmed → false",
            category: "lifecycle",
            tintName: "orange",
            timestamp: .now
        )

        NotificationCenter.default.post(
            name: .wealthTradingLifecycleDidDisarm,
            object: nil
        )
    }

    // MARK: - Gate predicate

    /// `true` when the gate is armed and Activity reconciliation may
    /// proceed.
    ///
    /// Downstream Activity-admission code should guard on this property
    /// before running timing-dependent checks (session open, queue windows,
    /// cash availability) to prevent premature admission rejections during
    /// the startup phase (Issue 4 fix).
    var canActivityAdmissionProceed: Bool {
        isArmed
    }
}

// MARK: - Notification names

extension Notification.Name {
    /// Posted on the main thread when `tradingLifecycleArmed` transitions
    /// from `false` to `true`.
    static let wealthTradingLifecycleDidArm = Notification.Name(
        "WealthTradingLifecycleDidArm"
    )

    /// Posted on the main thread when `tradingLifecycleArmed` transitions
    /// from `true` to `false`.
    static let wealthTradingLifecycleDidDisarm = Notification.Name(
        "WealthTradingLifecycleDidDisarm"
    )
}
