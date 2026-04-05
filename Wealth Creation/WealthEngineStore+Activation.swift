import Foundation

// MARK: - WealthEngineStore+Activation
//
// Thin delegation shim — all startup logic lives in WealthEngineStartupController.
//
// `runActivationSequence()` is the entry point called by WealthCore.swift
// (not in git).  It now simply forwards to the canonical startup controller
// so there is exactly one place that owns the startup sequence, eliminating
// the previous dual-path divergence risk.

extension WealthEngineStore {

    // MARK: - Activation sequence

    /// Delegates to `WealthEngineStartupController.shared.beginStartupSequence()`.
    ///
    /// All idempotency guards, phase sequencing, timer scheduling, and
    /// ready-state signalling are handled by the controller.
    func runActivationSequence() {
        WealthEngineStartupController.shared.beginStartupSequence()
    }
}
