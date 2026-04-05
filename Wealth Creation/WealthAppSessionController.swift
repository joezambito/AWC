import SwiftUI
import Combine

@MainActor
final class WealthAppSessionController {

    static let shared = WealthAppSessionController()
    static let visibleAppStateDidResetNotification = Notification.Name("awc_visible_app_state_did_reset")

    private enum StorageKey {
        static let oneTimeDashboardResetToken = "awc_one_time_dashboard_reset_20260323b"
    }

    private var hasLaunched = false
    private var resetObserver: AnyCancellable?
    private let defaults = UserDefaults.standard

    private init() {
        resetObserver = NotificationCenter.default.publisher(
            for: WealthAppSessionController.visibleAppStateDidResetNotification
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.clearForVisibleAppReset()
        }

        if let cacheURL = WealthMarketUniverseStartupCache.snapshotFileURL(),
           FileManager.default.fileExists(atPath: cacheURL.path) {
            defaults.removeObject(forKey: WealthMarketUniverseStartupCache.legacyDefaultsKey)
        }
    }

    // MARK: - Lifecycle entry-points

    /// Call once on app launch from ContentView's `.task` modifier.
    ///
    /// Performs a one-time dashboard reset (if the token has not been set),
    /// activates pipeline singletons, restores the engine cache off the main
    /// thread, and starts the staggered startup sequence.
    func prepareLaunch(isUnlocked: Binding<Bool>) {
        guard !hasLaunched else { return }
        hasLaunched = true

        WealthStartupLagTracer.shared.trace("prepareLaunch – start")

        // One-time dashboard reset: force the lock screen on the very first
        // launch after this token was introduced so any stale UI is cleared.
        if !defaults.bool(forKey: StorageKey.oneTimeDashboardResetToken) {
            defaults.set(true, forKey: StorageKey.oneTimeDashboardResetToken)
            isUnlocked.wrappedValue = false
        }

        WealthNewComponentsBootstrap.activate()
        WealthStartupLagTracer.shared.trace("prepareLaunch – pipeline singletons activated")

        WealthEngineStore.shared.restoreCacheInBackground {
            WealthStartupLagTracer.shared.trace("prepareLaunch – cache restore complete; startup sequence beginning")
            WealthEngineStartupController.shared.beginStartupSequence()
        }

        WealthEventLogStore.shared.record(
            title: "Session Controller",
            detail: "prepareLaunch: cache restore started, startup sequence queued.",
            category: "lifecycle",
            tintName: "blue",
            timestamp: .now
        )
    }

    /// Called from ContentView's `onChange(of: isUnlocked)`.
    ///
    /// When the app is unlocked, triggers an immediate resume check so AI Live
    /// and Activity are refreshed without waiting for the next timer tick.
    /// When locked, cancels any in-flight session resume.
    func syncSession(unlocked: Bool, phase: ScenePhase) {
        WealthStartupLagTracer.shared.trace("syncSession – unlocked=\(unlocked)")
        if unlocked {
            WealthEngineRuntimeCoordinator.shared.handleBecameActive()
        } else {
            WealthSessionUnlockController.shared.cancelSessionResume()
        }
    }

    /// Called from ContentView's `onChange(of: scenePhase)`.
    ///
    /// Bridges scene-phase transitions to the pipeline:
    ///   • `.active`     → runtime coordinator evaluates a resume if unlocked.
    ///   • `.background` → cancel pending resume and persist engine state.
    ///   • `.inactive`   → no-op.
    func handlePhaseChange(_ phase: ScenePhase, isUnlocked: Binding<Bool>) {
        WealthStartupLagTracer.shared.trace("handlePhaseChange – phase=\(phase)")
        switch phase {
        case .active:
            if isUnlocked.wrappedValue {
                WealthEngineRuntimeCoordinator.shared.handleBecameActive()
            }
        case .background:
            WealthSessionUnlockController.shared.cancelSessionResume()
            WealthEngineStore.shared.saveInBackground()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Private

    private func clearForVisibleAppReset() {
        WealthEventLogStore.shared.record(
            title: "Session Controller",
            detail: "clearForVisibleAppReset: visible app state reset handled.",
            category: "lifecycle",
            tintName: "orange",
            timestamp: .now
        )
    }
}
