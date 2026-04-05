# AWC Deep Audit Report
**Generated:** 2026-04-05  
**Scope:** All committed Swift source files in `Wealth Creation/` (43 files, 5 412 lines), `Tests/AWCTests/AWCTests.swift`, `Package.swift`  
**Basis:** Direct file-by-file reading of the current `main` branch. No findings are carried from prior sessions.

---

## Executive Summary

The AWC codebase contains a well-structured pipeline with explicit threading separation and audit instrumentation. However, **the entire scan/AI/market pipeline does no real work**: all five core engine methods are empty stubs that delegate to `WealthCore.swift`, which is **not committed to the repository**. Beyond this critical structural gap, 25 distinct issues were found ranging from concurrency safety risks to data-correctness bugs, each with measurable impact on app performance and reliability.

Issues are grouped by severity:
- 🔴 **Critical** — silently produces no output or causes data corruption
- 🟠 **High** — causes visible lag, UI freezes, or incorrect results at runtime
- 🟡 **Medium** — reliability risk under load or unusual conditions
- 🔵 **Low** — code quality / future-maintenance concern

---

## 🔴 CRITICAL

---

### CRIT-1: All five core engine scan methods are empty stubs — the pipeline does nothing
**File:** `WealthEngineStore+Refresh.swift` · Lines 103–138  
**Also:** `WealthEngineStore.swift` · Lines 188–205

```swift
// Line 103
@MainActor
func performUniverseScan() {
    // Implemented in WealthCore.swift (existing engine logic).
}

// Line 110
@MainActor
func performAIScan() {
    WealthBrainStore.shared.ingest(...)  // ← only audit side-effect; no scan
}

// Line 123
@MainActor
func performMarketRanking() {
    materializeMarketCandidates()  // ← called, but depends on stub data
}

// Line 129
@MainActor
func performResearchFeeds() {
    // Implemented in WealthCore.swift
}

// Line 134
@MainActor
func performIBKRSync() {
    // Implemented in WealthCore.swift
}
```

And in `WealthEngineStore.swift`:
```swift
// Line 193
func runStartupActivationScan() async {
    // Delegates to the AI brain scan pipeline in WealthCore.swift.
}

// Line 202
func runStartupMarketWarmup() async {
    // Delegates to the market-warmup pipeline in WealthCore.swift.
}
```

**Description:** `WealthCore.swift` — the file that contains the actual universe-download, AI-scoring, and market-warmup logic — is **not in the git repository** (it appears only in `DerivedDataLocalMac` build artifacts). All five `perform*` methods and both startup stubs have empty bodies. Every timer callback and startup sequence invokes these methods and receives zero data in return.

**Impact on performance and reliability:**
- `rankedAssets`, `scannedSignals`, and `holdings` are always empty after startup. The UI will always show zero cards, zero holdings, and zero P&L.
- `materializeMarketCandidates()` (called from the stub `performMarketRanking()`) runs on an empty `rankedAssets` array — it processes no data and produces no ranked cards for Activity.
- `WealthBrainStore.shared.ingest()` is called but `learn()` and `bias()` inside it are also stubs (see CRIT-2), so even the AI-scoring side-effect is no-op.
- Every timer (9 m, 10 m, 19 m, 20 m, 29 m, 30 m) fires, completes instantly with zero data, and loops indefinitely — burning battery and CPU wake cycles without producing results.
- Activity queue stays permanently empty. Live trading never arms.

---

### CRIT-2: WealthBrainStore.learn() and bias() are empty stubs
**File:** `WealthBrainStore.swift` · Lines 85–93

```swift
func learn() {
    // Implemented in WealthCore.swift (existing engine logic).
}

func bias() {
    // Implemented in WealthCore.swift (existing engine logic).
}
```

**Description:** The AI brain's two core primitives have no implementation. `ingest()` calls `learn()` on every soft and deep refresh cycle, but `learn()` never updates any model state.

**Impact on performance and reliability:**
- AI scores on `Opportunity` objects are never updated by the brain. `aiScore` remains at its initialised value (0 or whatever the previous persist contained).
- Cards with `aiScore == 0` fail the AI Live promotion filter in `WealthAILiveCoordinator+Evaluation.swift` (line 101), so promoted card count is always zero regardless of universe size.
- Activity remains empty. Live-trading decision logic has no learned signal to act on.

---

### CRIT-3: earningsRisk and macroRisk are semantically incorrect placeholder derivations used in live safeguard gates
**File:** `Opportunity+CardStateMachine.swift` · Lines 68–93

```swift
// Line 68 — earningsRisk
var earningsRisk: Int {
    // ⚠️ PLACEHOLDER – Replace this computed property...
    // The current derivation from the generic `risk` float is NOT semantically
    // equivalent to earnings-specific risk and WILL produce incorrect safeguard
    // decisions in production until replaced.
    Int((risk * 100).rounded())
}

// Line 83 — macroRisk
var macroRisk: Int {
    // ⚠️ PLACEHOLDER – Replace this computed property...
    // The current inverted-probability calculation is NOT semantically
    // equivalent to macro risk and WILL produce incorrect safeguard
    // decisions in production until replaced.
    Int(((1.0 - probability) * 100).rounded())
}
```

**Description:** Both properties power the safeguard gate in `WealthEngineStore+Materialization.swift` (lines 113–117) and in the AI Live coordinator (lines 105–106). A card with `risk ≥ 0.70` will be rejected as "earningsRisk ≥ 70" even if no earnings event exists. A card with `probability ≤ 0.25` will be rejected as "macroRisk ≥ 75" regardless of actual macro conditions.

**Impact on performance and reliability:**
- Cards that should flow into Market ranking are silently rejected with wrong reasons. The materialization funnel (128 k → 208 → 42 reported in comments) will shrink further than intended.
- The `WealthMarketExecutionAuditReport` and `WealthAILiveRejectionAuditReport` will report inflated `earningsRisk` and `macroRisk` rejection counts that do not reflect real risk conditions.
- Any operational tuning of the `SafeguardThreshold` constants (70/75) based on audit report numbers will be tuning against wrong data, making the app's safeguard calibration unreliable.

---

## 🟠 HIGH

---

### HIGH-1: nonisolated(unsafe) on timerHolder bypasses Swift concurrency safety
**File:** `WealthEngineStore+Timers.swift` · Line 31

```swift
private nonisolated(unsafe) let timerHolder = WealthTimerHolder()
```

**Description:** `nonisolated(unsafe)` instructs the Swift concurrency checker to ignore actor-isolation requirements for this value. The comment asserts that access is always serialised on `@MainActor`. However, `Timer.scheduledTimer` callbacks fire on the RunLoop of the thread that *scheduled* them. If `scheduleRecurringTimers()` is called off the main thread (e.g., from a detached Task that hasn't hopped to MainActor), `timerHolder` is mutated without isolation, creating a data race.

**Impact on performance and reliability:**
- If `timerHolder.ibkrTimers` or `timerHolder.extraSoftTimers` is mutated on two threads simultaneously (one scheduling, one invalidating), the array can become corrupted. Depending on the runtime, this manifests as a crash, a missed invalidation (timer accumulation), or a dangling `Timer` reference.
- Suppressing the concurrency check means the compiler will not warn if a future refactor breaks the invariant.

---

### HIGH-2: Two parallel startup paths can both fire, causing duplicate scan work
**Files:**  
- `WealthEngineStore+Bootstrap.swift` → `WealthAppSessionController.prepareLaunch()` → `WealthEngineStartupController.beginStartupSequence()`  
- `WealthEngineStore+Activation.swift` · `runActivationSequence()`

**Description:** `WealthAppSessionController.prepareLaunch()` (called from `bootstrap()`) triggers `WealthEngineStartupController.beginStartupSequence()`. At the same time, `WealthEngineStore.runActivationSequence()` is a fully independent path, also callable externally, that runs its own universe download, AI scan, and market warmup sequence. Both paths:
1. Have their own idempotency guards (`hasLaunched`, `startupTask == nil`) that are *independent of each other*.
2. Schedule timers on completion (`rescheduleTimers()`).
3. Write to the same `@Published` properties.

If both are ever triggered (e.g., if any remaining WealthCore.swift call sites invoke `runActivationSequence()` while `prepareLaunch()` is also called), six timers from path A and another six timers from path B will all be scheduled. Each subsequent 30-minute tick will then run two full deep refreshes.

**Impact on performance and reliability:**
- Double timer scheduling causes the app to perform twice the network I/O and CPU computation per cycle.
- Two concurrent writes to `rankedAssets` and other `@Published` properties (even though each hop to @MainActor) interleave unpredictably, producing a mixed ranking result.
- Battery life and data usage double for no user benefit.

---

### HIGH-3: WealthAppSessionController.applicationWillTerminate() calls synchronous save on main thread
**File:** `WealthAppSessionController.swift` · Line 149

```swift
func applicationWillTerminate() {
    WealthEngineStore.shared.save()  // ← synchronous encode + write on main thread
    ...
}
```

And `WealthEngineStore+Cache.swift` · Lines 69–79:
```swift
func save() {
    let bundle = EngineStateBundle(rankedAssets: rankedAssets, ...)
    PersistenceManager.shared.saveBundle(bundle)  // JSONEncoder + write on caller's thread
}
```

**Description:** `save()` JSON-encodes `rankedAssets` (potentially 128 000 `Opportunity` objects), `scannedSignals`, and `holdings` synchronously on the main thread in the termination handler. iOS/macOS gives an app approximately 5 seconds to return from `applicationWillTerminate` before the watchdog kills it.

**Impact on performance and reliability:**
- Encoding 128 k complex objects can easily exceed 5 seconds, triggering a watchdog termination. The save never completes and data from the current session is lost.
- On every termination following a deep refresh, the app appears to hang momentarily before the OS force-kills it, which users may interpret as a crash.

---

### HIGH-4: WealthEngineStore+Recovery.restoreCache() is called synchronously on the main thread during failure recovery
**File:** `WealthEngineStore+Recovery.swift` · Line 32

```swift
func recoverFromFailedRefresh(reason: String) {
    ...
    restoreCache()  // ← synchronous JSON decode on main thread
    ...
}
```

**Description:** `restoreCache()` in `WealthEngineStore+Cache.swift` (line 73) calls `PersistenceManager.shared.loadBundle()` which reads and JSON-decodes the full state bundle (`awc_engine_state_bundle.json`) synchronously on the calling thread. `recoverFromFailedRefresh()` is called from `WealthEngineRuntimeRecovery.performFullRecovery()` which itself can be triggered from any context, including the main actor.

**Impact on performance and reliability:**
- Decoding 128 k ranked assets from JSON on the main thread takes multiple seconds, freezing all UI interaction (tab switches, scroll, button taps) for the duration.
- Recovery is the hot path after a crash or connectivity failure — exactly when user responsiveness matters most.

---

### HIGH-5: WealthEngineStore+Refresh task double-wrapping defeats concurrency intent
**File:** `WealthEngineStore+Refresh.swift` · Lines 48–81

```swift
func runUniverseScan() async {
    await Task.detached(priority: .userInitiated) { [weak self] in
        await self?.performUniverseScan()  // @MainActor method
    }.value
}
```

**Description:** Each `run*` public method launches a `Task.detached` (which runs on a background cooperative thread), then immediately awaits a `@MainActor`-isolated method (`performUniverseScan()`, etc.). Swift's actor system immediately hops back to the main actor to execute the `@MainActor` function. The background thread does nothing except schedule the hop. The net effect is: main actor → background thread → main actor, adding two context switches per scan step.

**Impact on performance and reliability:**
- Four unnecessary context switches per timer cycle (universe, AI, market, research) plus three for IBKR price syncs = 42+ redundant thread hops per 30-minute cycle.
- During startup (which runs universe + AI + market + research sequentially), four additional context switches extend the critical path by measurable milliseconds, delaying the point at which the UI can show data.
- If the implementation in WealthCore.swift performs actual I/O inside the `@MainActor` stub overrides, this means all I/O runs on the main actor, defeating the entire threading architecture.

---

### HIGH-6: WealthPeerSyncService uses .main queue for NWListener and NWBrowser callbacks
**File:** `WealthPeerSyncService.swift` · Lines 93, 129

```swift
l.start(queue: .main)   // Line 93
b.start(queue: .main)   // Line 129
```

**Description:** NWListener and NWBrowser are directed to deliver their state-update and results-changed callbacks on the main dispatch queue. By contrast, `WealthIBKRBridge` (correctly) uses a dedicated `ibkrNetworkQueue` for NWConnection to avoid this problem. The peer sync service does the opposite, funnelling all Bonjour TCP events through the main queue alongside UI events.

**Impact on performance and reliability:**
- When peer discovery is active (e.g., multiple AWC devices on the same LAN), continuous `browseResultsChangedHandler` callbacks flood the main queue. This competes with UI rendering callbacks and can cause frame drops, sluggish scrolling, and delayed touches.
- If a network transition occurs (Wi-Fi → cellular, SSID change), the resulting burst of NWBrowser state changes and results updates arrives on the main queue simultaneously with scan-phase notifications and SwiftUI view updates, creating a worst-case queue depth that can stall the UI for hundreds of milliseconds.

---

### HIGH-7: WealthEngineStore+Activation defer block does not call endDashboardRefreshFreeze on normal completion
**File:** `WealthEngineStore+Activation.swift` · Lines 57–67

```swift
activationTask = Task { @MainActor [self] in
    defer {
        if Task.isCancelled {
            pendingRefreshPayload = nil
            startupSequencePhase = .idle
            endDashboardRefreshFreeze()  // ← only on cancellation
        }
        activationTask = nil
    }
    ...
}
```

**Description:** `endDashboardRefreshFreeze()` (which sets `isDashboardRefreshInFlight = false`) is called only when `Task.isCancelled` is true. On normal successful completion of the activation sequence, it is never called. If any caller set `isDashboardRefreshInFlight = true` before invoking `runActivationSequence()` (which is the typical pattern — show a spinner, run startup, hide spinner), the spinner flag remains `true` permanently after a successful run.

**Impact on performance and reliability:**
- The dashboard loading spinner (or whatever UI state is gated on `isDashboardRefreshInFlight`) remains active indefinitely after a clean startup, confusing users into thinking the app is still loading.
- Any UI component that disables interaction while `isDashboardRefreshInFlight` is true (e.g., form inputs, trade buttons) stays disabled forever.

---

### HIGH-8: WealthDownstreamRebuildOrchestrator and WealthSessionUnlockController silently drop re-entrant requests
**Files:**  
- `WealthDownstreamRebuildOrchestrator.swift` · Lines 46–48  
- `WealthSessionUnlockController.swift` · Lines 36–38

```swift
// Orchestrator
func triggerRebuild(reason: String) {
    guard rebuildTask == nil else { return }  // silent drop
    ...
}

// UnlockController
func handleSessionResume() {
    guard resumeTask == nil else { return }  // silent drop
    ...
}
```

**Description:** Both guards are designed to prevent duplicate work. However, there is no mechanism to re-attempt a dropped request once the in-flight task completes. If `checkAndRebuildIfNeeded()` is called while a rebuild is in-flight (e.g., due to rapid foreground/background transitions), the second detection is silently discarded. The in-flight rebuild may have been triggered by a *different* stale condition that has since been resolved, meaning the new condition is never addressed until the next timer tick (up to 10 minutes later).

**Impact on performance and reliability:**
- After a rapid double-foreground event (lock → unlock → background → foreground within 2 seconds, common in password-manager or notification interactions), the second resume's rebuild is dropped. Activity and AI Live scores remain stale until the next 10-minute soft-refresh fires.
- Under network retry conditions (burst of foreground activations while reconnecting), multiple stale-cache detections are all dropped, leaving the user with an empty Activity list for the full timer interval.

---

## 🟡 MEDIUM

---

### MED-1: WealthEngineStore+Activation inner Task.detached completes UI state updates after activationTask = nil
**File:** `WealthEngineStore+Activation.swift` · Lines 74–108

```swift
activationTask = Task { @MainActor [self] in
    defer { activationTask = nil }   // ← sets nil when outer task ends

    await Task.detached(priority: .userInitiated) { [weak self] in
        // ... actual work ...
        await MainActor.run {
            self.tradingLifecycleArmed = true   // ← UI state set here
            self.rescheduleTimers()
        }
    }.value
}
```

**Description:** The outer task's `defer` block runs after `await Task.detached(...).value` returns, which is correct. However, another call to `runActivationSequence()` racing between the inner task completing and the outer defer running would find `activationTask != nil` and be rejected. This race window is extremely narrow but exists.

More significantly: the idempotency guard `guard activationTask == nil` at the top of `runActivationSequence()` prevents recovery from a stuck/cancelled inner task unless `WealthEngineRuntimeRecovery.runStartupIntegrityCheck()` explicitly clears `activationTask = nil` (which it does, but only if `activationTask != nil` at check time — not after it was set to nil by the defer but before a new call arrives).

**Impact on performance and reliability:**
- A race between a factory reset (`WealthEngineRuntimeRecovery.performFullRecovery()`) and the normal completion of `runActivationSequence()` can clear `activationTask` twice without harm, but any call to `runActivationSequence()` in that window is silently dropped, delaying the next startup cycle.

---

### MED-2: WealthPortfolioLifecycleHelper retry loop clobbers retryTask without cancelling
**File:** `WealthPortfolioStore+LifecycleHelpers.swift` · Lines 83–90

```swift
private func scheduleArmedRetry(attemptsRemaining: Int) {
    ...
    retryTask = Task { [weak self] in   // ← previous retryTask reference lost
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        guard !Task.isCancelled, let self else { return }
        if WealthPortfolioStore.shared.tradingLifecycleArmed {
            self.triggerAdmissionRerun()
        } else {
            self.scheduleArmedRetry(attemptsRemaining: attemptsRemaining - 1)
        }
    }
}
```

**Description:** `retryTask` is overwritten on each recursive call without first cancelling the previous value. Although only one task is sleeping at a time (the recursion is sequential), if `cancelStartupSequence()` or any other code sets `retryTask = nil` externally between recursions, the previous `Task.sleep` will run to completion anyway because there is no cancellation bridge.

**Impact on performance and reliability:**
- Up to 30 one-second tasks can accumulate. Each task holds a closure capturing `self` (weak), but the `Task.sleep` itself is not cancellable via the `retryTask` reference once it has been overwritten. On slow devices, these tasks can stack up in the cooperative thread pool, delaying other concurrent work during the 30-second retry window.
- If `tradingLifecycleArmed` never becomes `true` (e.g., because WealthCore.swift is not wired), the helper silently gives up after 30 seconds and logs a red event. The app never triggers admission reconciliation, leaving Activity permanently empty.

---

### MED-3: WealthDownstreamCacheSanity notification observer can create a rebuild loop
**Files:**  
- `WealthDownstreamCacheSanity.swift` · Init observer (Lines 42–53)  
- `WealthReadyStateGate.swift` · `markDownstreamRebuildComplete()` (Lines 45–56)

**Description:** `WealthDownstreamCacheSanity.init()` registers an observer for `wealthEngineDidBecomeReady`. When the notification fires, `validatePersistedDownstreamState()` is called. If any cache is stale, `checkAndRebuildIfNeeded()` → `triggerRebuild()` → rebuild runs → `markDownstreamRebuildComplete()` → posts `wealthEngineDidBecomeReady` again → `validatePersistedDownstreamState()` is called again.

If the downstream cache files (`awc_ai_live_results.json`, `awc_market_snapshot.json`, `awc_activity_state.json`) are never saved (because `WealthNewComponentsBootstrap.runPostReadyPipeline()` depends on stub implementations), `isAILiveResultsFresh` and `isMarketSnapshotFresh` will always return `false`. Every rebuild completion will trigger another rebuild.

**Impact on performance and reliability:**
- A continuous rebuild cycle fires indefinitely at the maximum speed of `runAIScan()` + `runMarketRanking()` (both stubs, so currently very fast, but with real data: 2–5 minutes each). Battery drain, CPU contention, and network usage compound with each cycle.
- The `WealthEngineScanScheduler.completedPhases` set is never reset between rebuilds (no call to `WealthEngineScanScheduler.shared.reset()`), so subsequent rebuild passes see `currentProgress == 1.0` from the first startup, meaning `hasReachedAILiveGate` is always `true` even if data is actually absent.

---

### MED-4: AWCSecretConfig can only be loaded once — no runtime reload mechanism
**File:** `AWCSecretConfig.swift` · Lines 95–97

```swift
func loadDotEnv() {
    guard values.isEmpty else { return }  // ← won't reload if called again
    ...
}
```

**Description:** `loadDotEnv()` is called once in `init()`. The `guard values.isEmpty` means subsequent calls (including manual retries) are no-ops. If `Documents/awc.env` doesn't exist at app launch (e.g., the user creates it after first launch), the configuration is never applied. There is no public reload API, no notification hook, and no watchdog for the file.

**Impact on performance and reliability:**
- `ibkrHost` returns `""` for the lifetime of the app if `awc.env` is absent at launch. `WealthIBKRBridge.connect()` checks for an empty host and calls `emit(.failed(...))`, meaning IBKR is permanently disconnected until the app is restarted.
- `marketDataBaseURL` returns `""`, so every `MarketDataFetcher.fetchQuote()` call throws `FetchError.missingBaseURL` permanently until restart.
- No user-visible error explains that a restart is needed after creating `awc.env`, making debugging difficult.

---

### MED-5: Timer scheduling uses Timer.scheduledTimer without explicit RunLoop registration
**File:** `WealthEngineStore+Timers.swift` · Lines 97, 110, 123

```swift
Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
    ...
}
```

**Description:** `Timer.scheduledTimer` adds the timer to the RunLoop of the *current thread* at the time of the call, in the `.default` mode. `scheduleRecurringTimers()` is an `@MainActor`-isolated method, so it currently runs on the main thread/RunLoop, which is correct. However, `.default` mode means timers do not fire while the main RunLoop is in `.tracking` mode (e.g., during a continuous scroll gesture or a `UIScrollView` pan).

**Impact on performance and reliability:**
- While a user is actively scrolling the market cards list or dragging a chart, all six recurring timers are paused. A 5-second scroll followed by a 30-minute timer means the IBKR price timer at 9 minutes fires at 9 minutes + scrolling duration. For heavy-scroll users, refreshes can be delayed by tens of seconds.
- The correct mode for background timers is `.common` (add via `RunLoop.main.add(timer, forMode: .common)`). Without `.common` mode, the app appears to "miss" refreshes during UI interaction.

---

### MED-6: WealthEngineStore has two legacy Timer properties that are immediately invalidated
**File:** `WealthEngineStore.swift` · Lines 143–152

```swift
var scheduledCheckpointTimer: Timer? = nil  // "Legacy...for compatibility with WealthCore.swift teardown"
var preScanBurstTimer: Timer? = nil         // "Legacy...retained for compatibility"
```

**Description:** Both properties are immediately invalidated and set to nil in `runActivationSequence()` (lines 42–46 of Activation.swift). The comments state they are retained for "compatibility with WealthCore.swift teardown paths". If WealthCore.swift creates these timers and then `runActivationSequence()` kills them before its own sequence completes, WealthCore.swift's intended timer-based logic is permanently broken after the first activation.

**Impact on performance and reliability:**
- Any timer-based scheduled work in WealthCore.swift that uses `scheduledCheckpointTimer` or `preScanBurstTimer` stops firing permanently after the first call to `runActivationSequence()`.
- Because these properties are public (`var`) on a `@MainActor` singleton, any extension or WealthCore.swift method can re-create them. This creates invisible coupling between the committed extension code and the uncommitted core, making the timer lifecycle unpredictable.

---

### MED-7: PersistenceManager.loadBundle() silently swallows file-read errors
**File:** `PersistenceManager.swift` · Lines 82–86

```swift
func loadBundle() -> EngineStateBundle? {
    guard let url = bundleURL else { return nil }
    guard let data = try? Data(contentsOf: url) else {
        Self.log.info("PersistenceManager.loadBundle: no bundle file found.")
        return nil
    }
    ...
}
```

**Description:** `try? Data(contentsOf: url)` treats a missing file and a permission/disk error identically. The log message `"no bundle file found"` is emitted for both cases, which is misleading when the actual error is a read failure.

**Impact on performance and reliability:**
- On a full disk or restricted sandbox, the bundle file exists but cannot be read. The app silently falls back to the legacy migration path, then to empty state, and the user sees 0 cards. No error is surfaced to the user or to the event log to explain why.
- The stale-cache rebuilder fires immediately (all downstream caches appear stale), triggering a full network reload. If the disk is full, the new download also fails silently, leaving the app in a permanent reload loop.

---

### MED-8: WealthAILiveCoordinator uses hardcoded magic numbers that duplicate SafeguardThreshold constants
**File:** `WealthAILiveCoordinator+Evaluation.swift` · Lines 98–99

```swift
let earningsRiskLimit = 70   // ← duplicates SafeguardThreshold.earningsRisk
let macroRiskLimit    = 75   // ← duplicates SafeguardThreshold.macroRisk
```

**Description:** `SafeguardThreshold` in `WealthEngineStore+Materialization.swift` (lines 34–35) defines these values as `static let earningsRisk: Int = 70` and `static let macroRisk: Int = 75`. The AI Live coordinator re-declares them as local constants rather than reading from `SafeguardThreshold`. The `WealthAILiveRejectionAudit` also uses literal `70` and `75` (lines 155, 161).

**Impact on performance and reliability:**
- If the threshold values are tuned (a routine operational task in a live trading system), they must be updated in three separate locations: `SafeguardThreshold`, `WealthAILiveCoordinator+Evaluation.swift`, and `WealthAILiveRejectionAudit.swift`. A partial update silently causes the safeguard gate and the AI Live gate to apply different thresholds, creating inconsistent pipeline behaviour (a card might pass the safeguard gate but be rejected by AI Live, or vice versa).

---

## 🔵 LOW

---

### LOW-1: nonisolated(unsafe) on ibkrNetworkQueue — annotation stronger than needed
**File:** `WealthIBKRBridge.swift` · Line 77

```swift
private nonisolated(unsafe) static let ibkrNetworkQueue = DispatchQueue(
    label: "com.awc.ibkr-bridge",
    qos: .userInitiated
)
```

**Description:** `ibkrNetworkQueue` is a `DispatchQueue` (a reference type that is internally thread-safe). A `static let` `DispatchQueue` can be declared with `nonisolated` (without `unsafe`) or as a global, since `DispatchQueue` satisfies `Sendable` in Swift 5.10+. `nonisolated(unsafe)` suppresses more checks than necessary.

**Impact:** Low risk since `DispatchQueue` itself is thread-safe. However, the `unsafe` annotation means the compiler silently ignores any future access-pattern issues around the queue reference, and future refactors that change the type of this variable will not get compiler warnings.

---

### LOW-2: WealthEngineStartupController.startupTask captures self weakly on a singleton
**File:** `WealthEngineStartupController.swift` · Line 64

```swift
startupTask = Task { [weak self] in
    await self?.runStartupSequence()
}
```

**Description:** `WealthEngineStartupController.shared` is a singleton (never deallocated). Using `[weak self]` means `self` is always non-nil, but every reference inside the task body requires an optional unwrap (`self?.`). More importantly, `runStartupSequence()` is called as `await self?.runStartupSequence()` — if `self` were nil (impossible for a singleton), the entire sequence silently does nothing with no log or error.

**Impact:** No immediate crash risk since `self` is never nil. However, the `[weak self]` pattern combined with `await self?.runStartupSequence()` (rather than `guard let self else { return }`) hides the nil path entirely. If the singleton is ever refactored to a non-singleton, this becomes a silent startup failure.

---

### LOW-3: WealthEngineScanScheduler.currentProgress is never reset between rebuild cycles
**File:** `WealthEngineScanScheduler.swift` · Lines 39–48

```swift
private(set) var currentProgress: Double = 0
private var completedPhases: Set<ScanPhase> = []
```

`reset()` exists but is only called by `WealthEngineRuntimeRecovery.runStartupIntegrityCheck()` indirectly through `WealthReadyStateGate.shared.reset()` (which does NOT call `WealthEngineScanScheduler.shared.reset()`). Neither the rebuild orchestrator nor the session unlock controller calls `reset()`.

**Description:** After startup completes with all 5 phases marked done (`currentProgress == 1.0`), the scheduler is never reset for subsequent rebuild cycles. Every subsequent call to `evaluateCandidates()` in `WealthAILiveCoordinator` sees `hasReachedAILiveGate == true` regardless of whether a fresh scan is actually in progress or complete, defeating the scan-progress gate entirely for all post-startup evaluations.

**Impact on reliability:** The scan-progress gate (designed to prevent AI Live evaluation against a partial universe) has no effect after the first startup. If a partial scan runs (e.g., only universe scan completes before a crash), the AI Live coordinator evaluates stale data anyway.

---

### LOW-4: WealthMarketExecutionAudit excludes weakGreen cards from the safeguard audit count
**File:** `WealthMarketExecutionAudit.swift` · Lines 101–116

```swift
let strongGreen = universe.filter(\.isStrongGreen)
let weakGreen   = universe.filter(\.isWeakGreen)

for card in strongGreen {
    switch engine.evaluateSafeguards(for: card) {
    ...
    }
}
// weakGreen cards are not evaluated by the safeguard gate
```

**Description:** The audit correctly mirrors the pipeline behaviour — only `strongGreen` cards go through the safeguard gate. However, `weakGreen.count` is included in the report as "Weak Green → Blue" without noting how many of those might have passed the safeguard gate had their P&L been above zero. The `WealthCardHoldingRouter.routeFromGreenCheckpoint()` output (which includes routing decisions) is not used in the audit, so the audit and the pipeline may diverge if `WealthCardHoldingRouter` applies additional routing rules.

**Impact on reliability:** Operators reading the audit report see `weakGreen` as a fixed count routed to Blue, but if the `WealthCardHoldingRouter` applies different criteria, the actual funnel numbers differ from the reported numbers. This makes operational tuning based on the audit report unreliable.

---

### LOW-5: WealthActivityAdmissionAudit counts requiresBrokerState and requiresSessionState identically
**File:** `WealthActivityAdmissionAudit.swift` · Lines 156–165

```swift
if !cardRejected {
    needsBrokerState += 1
}
if !cardRejected {
    needsSessionState += 1
}
```

**Description:** Both counters are incremented on the same condition and are always equal. The report shows them as two distinct values but they are redundant.

**Impact on reliability:** The audit report creates a false impression of two independent measurement dimensions. An operator seeing "Needs broker state: 5 / Needs session state: 5" cannot distinguish whether broker gating and session gating are being evaluated independently. This reduces the diagnostic value of the report.

---

### LOW-6: WealthEngineStore+Dashboard.publishDashboardUpdate() sends objectWillChange manually — redundant with @Published
**File:** `WealthEngineStore+Dashboard.swift` · Lines 52–54

```swift
func publishDashboardUpdate() {
    objectWillChange.send()  // manual send
}
```

**Description:** All `@Published` properties on `WealthEngineStore` automatically trigger `objectWillChange.send()` when their value changes. A manual `objectWillChange.send()` call (with no property change) will cause subscribed SwiftUI views to re-render but with no new data, wasting a full diff/render cycle.

**Impact on performance:** Every call to `publishDashboardUpdate()` (inside `beginDashboardRefresh()` and `endDashboardRefresh()`) triggers a complete SwiftUI view tree re-evaluation. During a deep refresh cycle, this fires twice (begin + end) on top of every `@Published` mutation, doubling the render work.

---

### LOW-7: WealthPeerSyncService.stop() clears discoveredPeers without notifying observers
**File:** `WealthPeerSyncService.swift` · Lines 55–62

```swift
func stop() {
    listener?.cancel()
    listener = nil
    browser?.cancel()
    browser = nil
    discoveredPeers.removeAll()  // @MainActor mutation but no @Published
}
```

**Description:** `discoveredPeers` is a plain stored property (not `@Published`). Any SwiftUI view or object observing `WealthPeerSyncService` would not receive automatic change notifications when `stop()` clears the peer list.

**Impact on reliability:** UI showing "N peers connected" would remain showing the last peer count after `stop()` is called, until the next manual render cycle. This is a stale-display bug.

---

### LOW-8: WealthIBKRBridge.receiveBuffer is declared `var` with public access (no `private`)
**File:** `WealthIBKRBridge.swift` · Line 69 (approximate, in the state section)

```swift
var receiveBuffer = Data()
```

**Description:** `receiveBuffer` is a mutable `Data` buffer that accumulates raw TCP bytes. It is declared with no access modifier, making it `internal` (visible to all code in the module). If any extension or WealthCore.swift code accidentally appends to or clears `receiveBuffer` at the wrong time, the handshake or message-framing parser will produce corrupt state.

**Impact on reliability:** A developer adding a new IBKR message handler in an extension might inadvertently mutate `receiveBuffer` outside the sanctioned `processReceiveBuffer()` path, causing framing errors, dropped messages, or a corrupted API state.

---

## Summary Table

| ID | File | Line(s) | Severity | Category |
|-----|------|---------|----------|----------|
| CRIT-1 | WealthEngineStore+Refresh.swift, WealthEngineStore.swift | 103–138, 188–205 | 🔴 Critical | Empty stubs — no scan work performed |
| CRIT-2 | WealthBrainStore.swift | 85–93 | 🔴 Critical | Empty stubs — AI brain has no effect |
| CRIT-3 | Opportunity+CardStateMachine.swift | 68–93 | 🔴 Critical | Wrong risk proxies in live safeguard gate |
| HIGH-1 | WealthEngineStore+Timers.swift | 31 | 🟠 High | `nonisolated(unsafe)` timerHolder — data-race risk |
| HIGH-2 | WealthEngineStore+Bootstrap.swift, +Activation.swift | multiple | 🟠 High | Dual startup paths — timer duplication risk |
| HIGH-3 | WealthAppSessionController.swift | 149 | 🟠 High | Synchronous save on main thread at termination |
| HIGH-4 | WealthEngineStore+Recovery.swift | 32 | 🟠 High | Synchronous cache restore on main thread in recovery |
| HIGH-5 | WealthEngineStore+Refresh.swift | 48–81 | 🟠 High | Double task wrapping — unnecessary main-actor hops |
| HIGH-6 | WealthPeerSyncService.swift | 93, 129 | 🟠 High | NWListener/NWBrowser on `.main` queue — UI starvation |
| HIGH-7 | WealthEngineStore+Activation.swift | 57–67 | 🟠 High | Dashboard freeze flag not cleared on normal completion |
| HIGH-8 | WealthDownstreamRebuildOrchestrator.swift, WealthSessionUnlockController.swift | 46–48, 36–38 | 🟠 High | Rebuild requests silently dropped on re-entry |
| MED-1 | WealthEngineStore+Activation.swift | 74–108 | 🟡 Medium | Narrow race window on activationTask nil-out |
| MED-2 | WealthPortfolioStore+LifecycleHelpers.swift | 83–90 | 🟡 Medium | Retry loop overwrites retryTask without cancelling |
| MED-3 | WealthDownstreamCacheSanity.swift + WealthReadyStateGate.swift | init, 45–56 | 🟡 Medium | Notification loop potential if caches never become fresh |
| MED-4 | AWCSecretConfig.swift | 95–97 | 🟡 Medium | Config loaded once — no reload without restart |
| MED-5 | WealthEngineStore+Timers.swift | 97, 110, 123 | 🟡 Medium | Timers in `.default` RunLoop mode — pause during scroll |
| MED-6 | WealthEngineStore.swift | 143–152 | 🟡 Medium | Legacy timers invalidated on activation — breaks WealthCore |
| MED-7 | PersistenceManager.swift | 82–86 | 🟡 Medium | File-read errors silently treated as "file not found" |
| MED-8 | WealthAILiveCoordinator+Evaluation.swift, WealthAILiveRejectionAudit.swift | 98–99, 155, 161 | 🟡 Medium | Threshold constants duplicated — divergence risk on tuning |
| LOW-1 | WealthIBKRBridge.swift | 77 | 🔵 Low | `nonisolated(unsafe)` stronger than needed for DispatchQueue |
| LOW-2 | WealthEngineStartupController.swift | 64 | 🔵 Low | Weak self on singleton task — misleading nil path |
| LOW-3 | WealthEngineScanScheduler.swift | 39–48 | 🔵 Low | Progress never reset between rebuild cycles |
| LOW-4 | WealthMarketExecutionAudit.swift | 101–116 | 🔵 Low | Audit may diverge from pipeline for weakGreen routing |
| LOW-5 | WealthActivityAdmissionAudit.swift | 156–165 | 🔵 Low | Broker and session state counters are always equal |
| LOW-6 | WealthEngineStore+Dashboard.swift | 52–54 | 🔵 Low | Manual `objectWillChange.send()` redundant with @Published |
| LOW-7 | WealthPeerSyncService.swift | 55–62 | 🔵 Low | `discoveredPeers` not @Published — stale UI on stop |
| LOW-8 | WealthIBKRBridge.swift | ~line 69 | 🔵 Low | `receiveBuffer` has internal access — mutation risk from extensions |

---

## Root Cause Priority Action

The single highest-leverage action is **committing `WealthCore.swift`** (or providing real implementations for the five stub methods in `WealthEngineStore+Refresh.swift` and `WealthEngineStore.swift`). Until those implementations exist, **the pipeline produces no data** regardless of the correctness of every other component. All 25 other issues become relevant only after the pipeline is producing real data.

Second priority: **replace the `earningsRisk` and `macroRisk` placeholder computations** (CRIT-3) before any live-trading is enabled, as they will silently reject valid candidates based on unrelated metrics.

Third priority: **fix the dashboard freeze flag leak** (HIGH-7) and the **synchronous main-thread saves** (HIGH-3, HIGH-4), as these will cause user-visible UI hangs and potential watchdog crashes immediately upon real data flowing through the pipeline.
