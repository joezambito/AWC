import Foundation

@MainActor
final class WealthAppSessionController {

    // MARK: - Shared instance

    static let shared = WealthAppSessionController()
    private init() {}

    // MARK: - Private state

    private var hasLaunched: Bool = false

    // MARK: - Lifecycle entry-points

    /// Call once on app launch (from your App struct init or AppDelegate).
    func prepareLaunch() {
        guard !hasLaunched else { return }
        hasLaunched = true

        WealthStartupLagTracer.shared.trace("prepareLaunch – start")

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

    /// Call from `sceneDidBecomeActive` / `applicationDidBecomeActive`.
    func applicationDidBecomeActive() {
        WealthStartupLagTracer.shared.trace("applicationDidBecomeActive – fired")

        WealthEngineRuntimeCoordinator.shared.handleBecameActive()

        WealthEventLogStore.shared.record(
            title: "Session Controller",
            detail: "applicationDidBecomeActive: runtime coordinator notified.",
            category: "lifecycle",
            tintName: "green",
            timestamp: .now
        )
    }

    /// Call from `sceneDidEnterBackground` / `applicationDidEnterBackground`.
    func applicationDidEnterBackground() {
        WealthSessionUnlockController.shared.cancelSessionResume()
        WealthEngineStore.shared.saveInBackground()

        WealthEventLogStore.shared.record(
            title: "Session Controller",
            detail: "applicationDidEnterBackground: state saved in background.",
            category: "lifecycle",
            tintName: "orange",
            timestamp: .now
        )
    }

    /// Call from `applicationWillTerminate`.
    func applicationWillTerminate() {
        WealthEngineStore.shared.saveInBackground()

        WealthEventLogStore.shared.record(
            title: "Session Controller",
            detail: "applicationWillTerminate: background save initiated.",
            category: "lifecycle",
            tintName: "orange",
            timestamp: .now
        )
    }
}
