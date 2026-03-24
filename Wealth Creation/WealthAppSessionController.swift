import SwiftUI

@MainActor
final class WealthAppSessionController {
    static let shared = WealthAppSessionController()

    private enum StorageKey {
        static let oneTimeDashboardResetToken = "awc_one_time_dashboard_reset_20260323b"
    }

    private init() {}

    func prepareLaunch(isUnlocked: Binding<Bool>) {
        performOneTimeDashboardResetIfNeeded()
        WealthLocalPriceAPIServer.shared.startIfNeeded()
        WealthEngineStore.shared.restoreDashboardSnapshotFromCurrentStores()
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
            lockSession(isUnlocked, phase: .background)
        @unknown default:
            WealthEngineRuntimeCoordinator.shared.setSessionEnabled(
                isUnlocked.wrappedValue,
                phase: phase
            )
        }
    }

    private func lockSession(_ isUnlocked: Binding<Bool>, phase: ScenePhase) {
        isUnlocked.wrappedValue = false
        WealthAuthStore.shared.lock()
        WealthEngineRuntimeCoordinator.shared.setSessionEnabled(false, phase: phase)
    }

    private func performOneTimeDashboardResetIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: StorageKey.oneTimeDashboardResetToken) == false else { return }

        WealthPortfolioStore.shared.resetAccountToZero()
        WealthBrokerStore.shared.resetBalancesToZero()
        let protection = WealthProtectionSettingsStore.shared
        protection.demoBalance = 0
        protection.demoMode = false
        protection.floorReserve = 0
        WealthEngineStore.shared.dashboardSnapshot = .init(
            cashBalance: 0,
            availableCapital: 0,
            committedCapital: 0,
            holdingsValue: 0,
            accountValue: 0,
            buyReserved: 0,
            sellReturning: 0,
            totalPnL: 0
        )
        defaults.set(true, forKey: StorageKey.oneTimeDashboardResetToken)
    }
}
