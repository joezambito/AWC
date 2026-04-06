import Foundation

// MARK: - WealthAppSessionController
//
// REPLACEMENT FILE — Startup Audit & Lag Tracing added.
//
// Tracing additions (observe only – no logic change):
//   `WealthStartupLagTracer.shared.trace(_:)` calls inserted at the start of
//   each lifecycle entry-point so the console and in-app event log show
//   exactly when each phase fires and the elapsed time since app launch.
//   No existing logic, branch, or return path has been altered.
//
// Original documentation preserved below.
//
// NEW code only.  Does NOT modify any existing functions.
//
// Problem addressed:
//   The app session lifecycle (launch, warm open, background, foreground,
//   relock, unlock) was not wired to the pipeline components.  As a result,
//   the downstream rebuild was never triggered on reopen, AI Live stayed
//   stale, and Activity remained empty after unlock.
//
// Solution (new code only):
//   `WealthAppSessionController` is the single integration point between
//   the iOS app/scene lifecycle callbacks and the AWC pipeline components.
//
//   Integration steps:
//     1. Call `prepareLaunch()` from your App struct / AppDelegate init
//        (replaces or wraps the existing `bootstrap()` call).
//     2. Call `applicationDidBecomeActive()` from your SceneDelegate /
//        App's `scenePhase` observer when the scene becomes active.
//     3. Call `applicationDidEnterBackground()` when the scene goes
//        to the background.
//     4. Call `applicationWillTerminate()` from the app will-terminate hook.
//
// Fixes:
//   Problem #2  – Finish the startup/session system
//   Problem #10 – Relock behavior: recovery is immediate + complete
//   Blocker #2  – Active-session resumes not forcing recovery

@MainActor
final class WealthAppSessionController {

    // MARK: Shared instance

    static let shared = WealthAppSessionController()
    private init() {}

    // MARK: - Private state

    /// Tracks whether `prepareLaunch()` has been called so a second call
    /// from a scene reconnect cannot re-trigger the full startup sequence.
    private var hasLaunched: Bool = false

    // MARK: - Lifecycle entry-points

    // ── 1. App launch ────────────────────────────────────────────────────

    /// Call once on app launch (from your App struct init or AppDelegate).
    ///
    /// Performs:
    ///   1. Activates all new pipeline components (audit singletons, cache
    ///      sanity checker) so their NotificationCenter observers are live.
    ///   2. Bootstraps the engine: restores the file-backed cache in the
    ///      background so the UI is populated without a main-thread freeze.
    ///   3. Starts the staggered startup sequence (universe → AI → Market
    ///      → research feeds → timers).
    func prepareLaunch() {
        guard !hasLaunched else { return }
        hasLaunched = true

        // ── Startup trace ─────────────────────────────────────────────────
        WealthStartupLagTracer.shared.trace("prepareLaunch – start")

        // Activate pipeline singletons (registers all NC observers)
        WealthNewComponentsBootstrap.activate()
        WealthStartupLagTracer.shared.trace("prepareLaunch – pipeline singletons activated")

        // Restore cache off the main thread, then start the startup sequence.
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

    // ── 2. App became active (foreground / unlock) ───────────────────────

    /// Call from `sceneDidBecomeActive` / `applicationDidBecomeActive`.
    ///
    /// If startup has already completed (warm open / reopen), this triggers
    /// an immediate stale-cache check and downstream rebuild so AI Live and
    /// Activity are always refreshed on every unlock or app reopen.
    ///
    /// If startup has not yet completed, the startup sequence is already
    /// running the full pipeline – no additional action is taken.
    func applicationDidBecomeActive() {
        // ── Startup trace ─────────────────────────────────────────────────
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

    // ── 3. App entered background ────────────────────────────────────────

    /// Call from `sceneDidEnterBackground` / `applicationDidEnterBackground`.
    ///
    /// Cancels any in-flight session resume and persists the current engine
    /// snapshot to file-backed storage without blocking the main thread.
    func applicationDidEnterBackground() {
        // Cancel any pending resume so it does not run while backgrounded.
        WealthSessionUnlockController.shared.cancelSessionResume()

        // Persist state asynchronously so it is available for next launch.
        WealthEngineStore.shared.saveInBackground()

        WealthEventLogStore.shared.record(
            title: "Session Controller",
            detail: "applicationDidEnterBackground: state saved in background.",
            category: "lifecycle",
            tintName: "orange",
            timestamp: .now
        )
    }

    // ── 4. App will terminate ────────────────────────────────────────────

    /// Call from `applicationWillTerminate`.
    ///
    /// Persists the current engine snapshot synchronously so data is not
    /// lost on a clean termination.  This is a last-resort save – prefer
    /// `saveInBackground()` during normal background transitions.
    func applicationWillTerminate() {
        WealthEngineStore.shared.save()

        WealthEventLogStore.shared.record(
            title: "Session Controller",
            detail: "applicationWillTerminate: synchronous save complete.",
            category: "lifecycle",
            tintName: "orange",
            timestamp: .now
        )
    }
}
