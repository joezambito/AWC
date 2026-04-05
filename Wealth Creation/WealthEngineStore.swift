import Foundation
import Combine

// MARK: - WealthEngineStore
//
// Core AWC engine singleton.  Declared @MainActor so that every extension
// method - and therefore every @Published property mutation - is guaranteed
// to run on the main thread.
//
// Root-cause threading fix:
//   Previously @Published updates could occur on any thread because the class
//   carried no actor annotation.  @MainActor on the class declaration ensures
//   all instance methods (including those defined in extensions) execute on
//   the main actor, making every @Published assignment thread-safe without
//   requiring per-site DispatchQueue.main.async wrappers.
//
// Engine logic is distributed across focused extension files (~200-300 lines
// each) to keep each unit of responsibility small and reviewable:
//
//   WealthEngineStore+Bootstrap.swift           - app launch / foreground hooks
//   WealthEngineStore+Activation.swift          - one-time startup activation
//   WealthEngineStore+Timers.swift              - recurring timer scheduling
//   WealthEngineStore+Refresh.swift             - refresh-mode dispatch
//   WealthEngineRefresh+LifecyclePublishing.swift - scan-progress notifications
//   WealthEngineStore+Materialization.swift     - market ranking / safeguard gate
//   WealthEngineStore+Cache.swift               - synchronous persistence
//   WealthEngineStore+BackgroundCache.swift     - off-thread persistence
//   WealthEngineStore+UniverseBlueprints.swift  - universe seed source
//   WealthEngineStore+Dashboard.swift           - snapshot helpers
//   WealthEngineStore+Recovery.swift            - error recovery / factory reset

// MARK: - StartupPhase

/// The current phase of the one-time startup activation sequence.
///
/// Used by `WealthEngineStore+Activation.swift` to track progress through
/// the pre-scan delay and heavy I/O steps so the UI can reflect the correct
/// loading state.
enum StartupPhase {
    case idle
    case waitingToScan
    case universeRefreshRunning
    case aiScanRunning
    case marketWarmupRunning
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

    // MARK: - Shared instance

    static let shared = WealthEngineStore()

    // MARK: - @Published properties
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

    /// Index (0-5) of the current timer-cycle activation stage.
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

    // MARK: - Non-published stored properties
    //
    // Every property below is mutated only through @MainActor-isolated
    // methods (class methods or extension methods on this @MainActor type).
    // No per-assignment DispatchQueue.main.async wrappers are required.

    /// Handle for the current startup activation `Task`.
    var activationTask: Task<Void, Never>? = nil

    /// Opaque payload reserved for a pending deferred refresh cycle.
    var pendingRefreshPayload: PendingRefreshPayload? = nil

    /// Handle for a pending publish task awaiting background completion.
    var pendingPublishTask: Task<Void, Never>? = nil

    /// Handle for the warm-start background refresh task.
    var warmStartRefreshTask: Task<Void, Never>? = nil

    /// Handle for a pending market materialization task.
    var pendingMarketMaterializationTask: Task<Void, Never>? = nil

    /// Handle for the scan-progress animation task.
    var scanProgressAnimationTask: Task<Void, Never>? = nil

    /// Timestamp when the scan-progress animation should end.
    var scanProgressAnimationEndsAt: Date? = nil

    /// Primary soft-refresh repeating timer.
    var softTimer: Timer? = nil

    /// Primary deep-refresh repeating timer.
    var heavyTimer: Timer? = nil

    /// Legacy checkpoint timer reference.
    var scheduledCheckpointTimer: Timer? = nil

    /// Legacy pre-scan burst timer reference.
    var preScanBurstTimer: Timer? = nil

    /// Total number of activation stages expected in this cycle.
    var activationStageTotal: Int = 0

    /// Number of locked-checkpoint intervals completed in the current cycle.
    var lockedCheckpointProgress: Int = 0

    /// `true` when a downstream cache-recovery pass is scheduled.
    var downstreamRecoveryPending: Bool = false

    /// Whether the engine has been bootstrapped at least once.
    var hasBootstrapped: Bool = false

    /// Whether cached market data is currently being used.
    var isUsingCachedMarketData: Bool = false

    /// When the app was last opened (used for refresh scheduling).
    var appOpenUpdatedAt: Date? = nil

    /// Configured interval (minutes) between soft refreshes.
    var configuredSoftRefreshMinutes: Double = 10

    /// Live AI evaluation results keyed by opportunity lane key.
    var aiLiveResultsByKey: [String: WealthAILiveResult] = [:]

    /// Activity refusal handoffs keyed by opportunity lane key.
    var activityRefusalsByKey: [String: WealthActivityRefusalHandoff] = [:]

    /// Current dashboard snapshot.
    var dashboardSnapshot: DashboardSnapshot = DashboardSnapshot()

    /// Whether warm-start card cache is usable.
    var hasUsableWarmStartCardCache: Bool {
        !rankedAssets.isEmpty && lastRefresh != nil
    }

    // MARK: - Constants

    static let lockedCheckpointCount: Int = 3
    static let phoneActivationStageCount: Int = 5

    // MARK: - Init

    private init() {}

    // MARK: - Startup scan stubs

    func runStartupActivationScan() async {}

    func runStartupMarketWarmup() async {
        // Implementation lives in WealthEngineScanScheduler.swift
    }

    // MARK: - Pipeline stubs (implementations in extension files or WealthCore.swift)

    func applyPendingRefreshState() async {}
    func refreshDownstreamPromotionStateAfterStartupGate() async {}
    func applyWarmStartVisibleState() {}
    func catchUpRecurringCyclesIfNeeded() {}
    func restorePersistedMarketCacheIfNeeded() {}
    func invalidatePersistedMarketRestoreGuard() {}
    func refreshAsync(mode: RefreshMode, publishToUI: Bool) async {}
    func save() {}

    // MARK: - Dashboard freeze helpers

    func endDashboardRefreshFreeze() {
        endDashboardRefresh()
    }
}
