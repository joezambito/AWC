import Foundation

// MARK: - WealthEngineStore+Activation
//
// Thin delegation shim — all startup logic lives in WealthAppSessionController
// and WealthEngineStartupController.
//
// `runActivationSequence()` is the entry point called by WealthCore.swift
// (not in git).  It now delegates to `WealthAppSessionController.prepareLaunch()`
// — the same path as `bootstrap()` — so cache restore always runs before the
// startup sequence begins, regardless of which ContentView hook fires first.
// `prepareLaunch()` is guarded by a `hasLaunched` flag so it is idempotent.

extension WealthEngineStore {

    // MARK: - Activation sequence

    /// Delegates to `WealthAppSessionController.shared.prepareLaunch()`.
    ///
    /// Routes through the same idempotent entry point as `bootstrap()` so
    /// cache restore always runs before the startup sequence begins,
    /// regardless of which ContentView hook fires first.
    func runActivationSequence() {
        WealthAppSessionController.shared.prepareLaunch()
    }
}
