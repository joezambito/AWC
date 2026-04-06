import SwiftUI

@MainActor
final class WealthAppSessionController {
    static let shared = WealthAppSessionController()
    static let visibleAppStateDidResetNotification = Notification.Name("awc_visible_app_state_did_reset")

    private enum StorageKey {
        static let oneTimeDashboardResetToken = "awc_one_time_dashboard_reset_20260323b"
    }

    private init() {}

    func prepareLaunch(isUnlocked: Binding<Bool>) {
        WealthEngineStore.shared.appOpenUpdatedAt = .now
        markLegacyDashboardResetHandledIfNeeded()
        if WealthSimulatorSessionSupport.unlockIfSupported(isUnlocked) {
            WealthEngineRuntimeCoordinator.shared.setSessionEnabled(true, phase: .active)
            return
        }
        lockSession(isUnlocked, phase: .inactive)
    }

    func syncSession(unlocked: Bool, phase: ScenePhase) {
        WealthEngineRuntimeCoordinator.shared.setSessionEnabled(unlocked, phase: phase)
    }

    func handlePhaseChange(_ phase: ScenePhase, isUnlocked: Binding<Bool>) {
        switch phase {
        case .active:
            WealthEngineRuntimeCoordinator.shared.setSessionEnabled(
                isUnlocked.wrappedValue,
                phase: .active
            )
        case .inactive:
            WealthEngineRuntimeCoordinator.shared.setSessionEnabled(
                isUnlocked.wrappedValue,
                phase: .inactive
            )
        case .background:
            if shouldRelockWhenBackgrounded, isUnlocked.wrappedValue {
                lockSession(isUnlocked, phase: .background)
            } else {
                WealthEngineRuntimeCoordinator.shared.setSessionEnabled(
                    isUnlocked.wrappedValue,
                    phase: .background
                )
            }
        @unknown default:
            WealthEngineRuntimeCoordinator.shared.setSessionEnabled(
                isUnlocked.wrappedValue,
                phase: phase
            )
        }
    }

    func resetVisibleAppStateToZero() {
        let engine = WealthEngineStore.shared
        engine.prepareForFreshLaunch()
        WealthMarketUniverseStore.prepareForVisibleAppReset()
        engine.resetCachedRuntimeStateToZero()
        engine.restoreDashboardSnapshotFromCurrentStores()
        NotificationCenter.default.post(name: Self.visibleAppStateDidResetNotification, object: nil)
    }

    func resetAccountAndVisibleAppStateToZero() {
        let engine = WealthEngineStore.shared
        engine.prepareForFreshLaunch()

        WealthPortfolioStore.shared.resetAccountToZero()
        WealthBrokerStore.shared.resetBalancesToZero()
        WealthMarketUniverseStore.prepareForVisibleAppReset()

        let protection = WealthProtectionSettingsStore.shared
        protection.demoBalance = 0
        protection.demoMode = false
        protection.floorReserve = 0

        WealthPortfolioStore.shared.resetGoalProgressBaselines()
        engine.resetCachedRuntimeStateToZero()
        engine.restoreDashboardSnapshotFromCurrentStores()
        NotificationCenter.default.post(name: Self.visibleAppStateDidResetNotification, object: nil)
    }

    private func lockSession(_ isUnlocked: Binding<Bool>, phase: ScenePhase) {
        isUnlocked.wrappedValue = false
        WealthAuthStore.shared.lock()
        WealthEngineRuntimeCoordinator.shared.setSessionEnabled(false, phase: phase)
    }

    private var shouldRelockWhenBackgrounded: Bool {
#if targetEnvironment(simulator)
        false
#else
        true
#endif
    }

    private func markLegacyDashboardResetHandledIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: StorageKey.oneTimeDashboardResetToken) == false else { return }
        defaults.set(true, forKey: StorageKey.oneTimeDashboardResetToken)
    }
}
