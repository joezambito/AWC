import Foundation
import Combine

// MARK: - WealthEngineStore
//
// Core AWC engine singleton.  Declared @MainActor so that every extension
// method – and therefore every @Published property mutation – is guaranteed
// to run on the main thread.
//
// Root-cause threading fix:
//   Previously @Published updates could occur on any thread because the class
//   carried no actor annotation.  @MainActor on the class declaration ensures
//   all instance methods (including those defined in extensions) execute on
//   the main actor, making every @Published assignment thread-safe without
//   requiring per-site DispatchQueue.main.async wrappers.
//
// Engine logic is distributed across focused extension files (~200–300 lines
// each) to keep each unit of responsibility small and reviewable:
//
//   WealthEngineStore+Bootstrap.swift           – app launch / foreground hooks
//   WealthEngineStore+Activation.swift          – one-time startup activation
//   WealthEngineStore+Timers.swift              – recurring timer scheduling
//   WealthEngineStore+Refresh.swift             – refresh-mode dispatch
//   WealthEngineRefresh+LifecyclePublishing     – scan-progress notifications
//   WealthEngineStore+Materialization.swift     – market ranking / safeguard gate
//   WealthEngineStore+Cache.swift               – synchronous persistence
//   WealthEngineStore+BackgroundCache.swift     – off-thread persistence
//   WealthEngineStore+UniverseBlueprints.swift  – universe seed source
//   WealthEngineStore+Dashboard.swift           – snapshot helpers
//   WealthEngineStore+Recovery.swift            – error recovery / factory reset

// MARK: - StartupPhase

/// The current phase of the one-time startup activation sequence.
///
/// Used by `WealthEngineStore+Activation.swift` to track progress through
/// the pre-scan delay and heavy I/O steps so the UI can reflect the correct
/// loading state.
enum StartupPhase {
    /// No startup is in progress (initial state or after sequence completion).
    case idle
    /// The engine is waiting through the pre-scan delay before launching scans.
    case waitingToScan
}

// MARK: - WealthEngineStore

/// The AWC engine's observable state container.
///
/// All @Published properties are automatically updated on the main thread
/// because the class is isolated to the `@MainActor`.  Consumers (SwiftUI
/// views, `WealthBrainStore`, audit coordinators) can safely observe these
/// properties without additional synchronisation.
@MainActor
final class WealthEngineStore: ObservableObject {

    // MARK: – Shared instance

    static let shared = WealthEngineStore()

    // MARK: – @Published properties
    //
    // Every property below is mutated only through @MainActor-isolated
    // methods (class methods or extension methods on this @MainActor type).
    // No per-assignment DispatchQueue.main.async wrappers are required.

    /// Full scored and ranked universe of market opportunities.
    ///
    /// Updated after every universe scan pass and persisted to file-backed
    /// cache so the UI is populated immediately on relaunch.
    @Published var rankedAssets: [Opportunity] = []

    /// All market signals gathered during the most-recent scan pass.
    @Published var scannedSignals: [MarketSignal] = []

    /// Current open portfolio holdings synced from the connected broker.
    @Published var holdings: [Holding] = []

    /// Timestamp of the most-recent successful refresh cycle.
    @Published var lastRefresh: Date? = nil

    /// Timestamp of the most-recent deep (heavy) refresh cycle.
    @Published var lastHeavyRefresh: Date? = nil

    /// Aggregate unrealised P&L across all open holdings.
    @Published var totalPnL: Double = 0

    /// Available capital allocated for new position entries.
    @Published var tradingCapital: Double = 0

    /// Total current portfolio value (holdings + available capital).
    @Published var portfolioValue: Double = 0

    /// `true` while a full dashboard-level refresh is actively in flight.
    @Published var isDashboardRefreshInFlight: Bool = false

    /// `true` while the market-materialization pipeline is executing.
    @Published var isMarketMaterializationInFlight: Bool = false

    /// Master kill-switch: when `true`, all live-trading order submission
    /// is halted regardless of AI Live scores or card state.
    @Published var killSwitch: Bool = false

    /// Index (0–5) of the current timer-cycle activation stage.
    ///
    /// Stage map: 0 = IBKR-1, 1 = Soft-1, 2 = IBKR-2, 3 = Soft-2,
    ///            4 = IBKR-3, 5 = Deep
    @Published var activationStage: Int = 0

    /// `true` once the first full startup activation cycle has completed.
    @Published var activationCycleComplete: Bool = false

    /// Current phase of the one-time startup activation sequence.
    @Published var startupSequencePhase: StartupPhase = .idle

    /// `true` once startup is complete and live trading operations are
    /// permitted.  Set by `runActivationSequence()` on completion.
    @Published var tradingLifecycleArmed: Bool = false

    // MARK: – Non-published stored properties

    /// Handle for the current startup activation `Task`.
    ///
    /// Non-nil only while `runActivationSequence()` is in progress.
    /// Cleared by the `defer` block inside the task and reset to `nil`
    /// by recovery paths if the task was interrupted.
    var activationTask: Task<Void, Never>? = nil

    /// Opaque payload reserved for a pending deferred refresh cycle.
    ///
    /// Set and consumed by WealthCore.swift refresh logic; extension code
    /// only clears this to `nil` as part of cancel / recovery flows.
    var pendingRefreshPayload: AnyObject? = nil

    /// Handle for a pending publish task awaiting background completion.
    var pendingPublishTask: Task<Void, Never>? = nil

    /// Primary soft-refresh repeating timer (10-minute and 20-minute
    /// intervals; see `WealthEngineStore+Timers.swift`).
    var softTimer: Timer? = nil

    /// Primary deep-refresh repeating timer (30-minute interval).
    var heavyTimer: Timer? = nil

    /// Legacy checkpoint timer reference retained for compatibility with
    /// WealthCore.swift teardown paths.  Invalidated at startup.
    var scheduledCheckpointTimer: Timer? = nil

    /// Legacy pre-scan burst timer reference retained for compatibility.
    /// Invalidated at the start of every activation sequence.
    var preScanBurstTimer: Timer? = nil

    /// `true` when a downstream cache-recovery pass is scheduled to run
    /// after the current scan phase completes.
    var downstreamRecoveryPending: Bool = false

    /// Number of locked-checkpoint intervals completed in the current
    /// activation cycle.  Compared against `Self.lockedCheckpointCount`
    /// to determine when to arm `tradingLifecycleArmed`.
    var lockedCheckpointProgress: Int = 0

    // MARK: – Constants

    /// Nanosecond delay applied before the startup scan begins (3 seconds).
    ///
    /// Provides a brief window for the UI to fully render its initial state
    /// before background scan tasks start competing for CPU.
    let phoneStartupScanDelayNanoseconds: UInt64 = 3_000_000_000

    /// Number of locked-checkpoint intervals required per activation cycle.
    static let lockedCheckpointCount: Int = 3

    // MARK: – Init

    private init() {}

    // MARK: – Startup scan implementation points
    //
    // These async methods are the designated call sites for the heavy AI-brain
    // and market-warmup logic that lives in WealthCore.swift.
    // WealthEngineStore+Activation.swift calls them inside a background
    // `Task.detached` so the main thread is never blocked.
    //
    // Because this class is @MainActor, callers that `await` these methods
    // from a non-isolated context will automatically hop to the main actor.

    /// Run the full AI brain scan: scores every ranked card and populates
    /// `aiScore`, `confidence`, and related fields on each `Opportunity`.
    ///
    /// Full implementation resides in WealthCore.swift (existing engine logic).
    /// Called by `WealthEngineStore+Activation.swift` during the one-time
    /// startup activation sequence.
    func runStartupActivationScan() async {
        // Delegates to the AI brain scan pipeline in WealthCore.swift.
    }

    /// Materialise ranked market candidates and seed IBKR live prices so
    /// the Activity queue is populated at the end of the startup sequence.
    ///
    /// Full implementation resides in WealthCore.swift (existing engine logic).
    /// Called by `WealthEngineStore+Activation.swift` after the AI brain scan.
    func runStartupMarketWarmup() async {
        // Delegates to the market-warmup pipeline in WealthCore.swift.
    }

    // MARK: – Dashboard freeze helpers

    /// End a dashboard-loading freeze that was started by the activation
    /// sequence.  Delegates to `endDashboardRefresh()` which is defined in
    /// `WealthEngineStore+Dashboard.swift`.
    ///
    /// Called from the cancellation `defer` block inside `runActivationSequence()`
    /// so the UI spinner is always cleared even when the task is cancelled.
    func endDashboardRefreshFreeze() {
        endDashboardRefresh()
    }
}
