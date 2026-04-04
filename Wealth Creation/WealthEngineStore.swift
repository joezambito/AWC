import Foundation
import Combine

// MARK: - WealthEngineStore
//
// Core wealth-engine store.  The single source of truth for all UI-facing
// published state, in-flight flags, task handles, and the single recurring
// checkpoint timer.
//
// ── Startup entry-point ───────────────────────────────────────────────────
//
//   ContentView.onAppear
//     └─ WealthEngineStore.shared.bootstrap()
//          └─ WealthAppSessionController.shared.prepareLaunch()
//               ├─ WealthNewComponentsBootstrap.activate()
//               └─ restoreCacheInBackground { WealthEngineStartupController.beginStartupSequence() }
//
//   ContentView.onChange(scenePhase == .active)
//     └─ WealthEngineStore.shared.handleForegroundActivation()
//          └─ WealthAppSessionController.shared.applicationDidBecomeActive()
//               └─ WealthEngineRuntimeCoordinator.handleBecameActive()
//
// ── Timer design ─────────────────────────────────────────────────────────
//
//   ONLY `scheduledCheckpointTimer` is used.  The old `softTimer`,
//   `heavyTimer`, and `preScanBurstTimer` properties have been removed.
//   `rescheduleTimers()` (WealthEngineStore+Timers.swift) schedules a
//   single 10-minute repeating timer that drives soft and deep refreshes
//   via a checkpoint-count gate.

@MainActor
final class WealthEngineStore: ObservableObject {

    // MARK: - Singleton

    static let shared = WealthEngineStore()
    private init() {}

    // MARK: - Startup Sequence Phase

    enum StartupSequencePhase {
        /// No active startup in progress.
        case idle
        /// Startup has been triggered and is waiting for the pre-scan delay.
        case waitingToScan
        /// Universe, AI, or market scan is actively running.
        case scanning
        /// All phases complete; recurring timers are live.
        case complete
    }

    // MARK: - @Published: Market & Portfolio Data
    //
    // These drive the SwiftUI dashboard, opportunity list, and holdings
    // views.  Always write on @MainActor.

    @Published var rankedAssets: [Opportunity] = []
    @Published var scannedSignals: [MarketSignal] = []
    @Published var holdings: [Holding] = []

    // MARK: - @Published: Refresh Timestamps

    @Published var lastRefresh: Date? = nil
    @Published var lastHeavyRefresh: Date? = nil

    // MARK: - @Published: Portfolio Metrics

    @Published var totalPnL: Double = 0
    @Published var tradingCapital: Double = 0
    @Published var portfolioValue: Double = 0

    // MARK: - @Published: Startup / Activation State
    //
    // UI components observe these to show startup progress banners and
    // to gate actions that require a fully-armed engine.

    /// Current phase of the one-time startup sequence.
    @Published var startupSequencePhase: StartupSequencePhase = .idle

    /// Monotonically-increasing activation stage counter used by progress
    /// views.  Reset to 0 at the start of each activation; incremented by
    /// individual phase completions.
    @Published var activationStage: Int = 0

    /// `true` once the full startup activation cycle has completed at least
    /// once this session.  Remains `true` for the lifetime of the app.
    @Published var activationCycleComplete: Bool = false

    /// Number of checkpoint-timer fires that have occurred since the last
    /// deep-refresh cycle.  Counts from 0 to `lockedCheckpointCount`.
    @Published var lockedCheckpointProgress: Int = 0

    /// `true` once the engine is ready for live trading decisions.  Set to
    /// `true` at the end of the startup activation sequence.
    @Published var tradingLifecycleArmed: Bool = false

    // MARK: - Startup Constants

    /// Number of checkpoint-timer fires required to trigger a deep refresh.
    /// With a 10-minute timer interval: 3 fires = 30-minute deep-refresh cycle.
    static let lockedCheckpointCount: Int = 3

    /// Initial delay (nanoseconds) from `runActivationSequence()` being
    /// called to the first scan phase starting.  Allows the UI to become
    /// responsive before heavy background work begins.
    let phoneStartupScanDelayNanoseconds: UInt64 = 2_000_000_000   // 2 s

    // MARK: - In-Flight Flags
    //
    // Not @Published – there is no direct UI binding; the dashboard uses
    // `isDashboardRefreshInFlight` via `makeDashboardSnapshot()`.

    /// `true` while a dashboard refresh cycle is executing.
    var isDashboardRefreshInFlight: Bool = false

    /// `true` while the market-materialization (ranking + safeguard) pass is
    /// executing.  Guards against re-entrant calls.
    var isMarketMaterializationInFlight: Bool = false

    // MARK: - Async Task Handles
    //
    // Retained so they can be cancelled on reset / sign-out.

    /// The one-time activation-sequence task spawned by `runActivationSequence()`.
    var activationTask: Task<Void, Never>? = nil

    /// A pending publish task retained to prevent early deallocation.
    var pendingPublishTask: Task<Void, Never>? = nil

    /// Payload buffered for a deferred refresh; cleared on reset.
    var pendingRefreshPayload: Any? = nil

    // MARK: - Checkpoint Timer
    //
    // A SINGLE recurring timer drives all post-startup refreshes.
    // Do NOT add softTimer, heavyTimer, or preScanBurstTimer; use only this.

    /// The single recurring checkpoint timer.  Scheduled by
    /// `rescheduleTimers()` after the startup sequence completes, and
    /// after every foreground re-activation that requires a timer reset.
    var scheduledCheckpointTimer: Timer? = nil

    // MARK: - Recovery / Lifecycle Flags

    /// `true` when a downstream recovery rebuild is queued but has not yet run.
    var downstreamRecoveryPending: Bool = false

    /// Emergency kill-switch.  When `true`, all scan and refresh operations
    /// are short-circuited.  Reset via `resetToFactoryDefaults()`.
    var killSwitch: Bool = false

    // MARK: - Dashboard Freeze Helper

    /// Clears the dashboard-refresh in-flight flag and notifies observers.
    ///
    /// Called from the activation-sequence cleanup path when the task is
    /// cancelled, preventing the UI from spinning indefinitely.
    func endDashboardRefreshFreeze() {
        isDashboardRefreshInFlight = false
        objectWillChange.send()
    }

    // MARK: - Startup Scan Hooks
    //
    // These methods are stubs defined here so that the startup extensions
    // can call them.  The full implementations live in WealthCore.swift.
    // When WealthCore.swift is refactored, move the bodies here and remove
    // the WealthCore.swift originals.

    /// Heavy activation scan: scores all ranked opportunities with the
    /// AI brain and runs the market-warmup pipeline.
    func runStartupActivationScan() async {}

    /// Runs the first market-warmup pass at startup, materialising
    /// market candidates and seeding the IBKR price feed.
    func runStartupMarketWarmup() async {}
}
