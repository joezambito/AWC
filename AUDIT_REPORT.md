# AWC Swift Codebase – Critical Audit Report

**Date:** 2026-04-05  
**Scope:** All 33 Swift source files in `Wealth Creation/`  
**Directive:** Diagnosis only – no code added, removed, or changed  

---

## CRITICAL BUG #1 — Ranked Output Silently Discarded (Pipeline Broken)

**File:** `WealthEngineStore+Materialization.swift`  
**Lines:** 98–106  
**Function:** `materializeMarketCandidates()`

```swift
let ranked = assignMarketRanks(to: recheckPassed)   // ← computed but never stored

WealthAllCardsStore.shared.sync(
    opportunities: rankedAssets,   // ← uses pre-rank `rankedAssets`, NOT `ranked`
    ...
)
```

**Why Critical:**  
`assignMarketRanks()` is called and its result stored in `ranked`, but `ranked` is never assigned back to `rankedAssets` and is never passed to `WealthAllCardsStore.sync()`. The sync call instead passes the original `rankedAssets`, which has no ranks applied. Every card in `rankedAssets` retains `rank == 0` after materialization completes.

**Impact:**  
- `WealthAILiveCoordinator.evaluateCandidates()` filters `engine.rankedAssets.filter { $0.rank > 0 }` → returns **empty array every time**  
- AI Live evaluation always skips (no ranked market cards)  
- Activity is always empty — the entire downstream pipeline (Market → AI Live → Activity) produces zero output every cycle  
- This is the root cause of the permanent empty Activity state  

---

## CRITICAL BUG #2 — Dual Competing Startup Paths

**Files:**  
- `WealthEngineStore+Activation.swift` — `runActivationSequence()`  
- `WealthEngineStartupController.swift` — `beginStartupSequence()`  
- `WealthAppSessionController.swift` — `prepareLaunch()`

**Lines:**  
- `WealthEngineStore+Activation.swift:38–107`  
- `WealthEngineStartupController.swift:50–120`  
- `WealthAppSessionController.swift:58–77`

**Why Critical:**  
Two independent startup pipeline implementations exist and are not coordinated:

- **Path A** (`runActivationSequence()`): Calls `WealthMarketUniverseStore.prepareCachedSnapshotForStartup()`, `runStartupActivationScan()`, `runStartupMarketWarmup()`, sets `activationCycleComplete`, `tradingLifecycleArmed`, `lockedCheckpointProgress`, `startupSequencePhase`, then calls `rescheduleTimers()`.

- **Path B** (`WealthEngineStartupController.beginStartupSequence()`): Calls `runUniverseScanWithProgress()`, `runAIScanWithProgress()`, `runMarketRankingWithProgress()`, `runResearchFeedsWithProgress()`, then calls `rescheduleTimers()`. **This is the path wired to `WealthAppSessionController.prepareLaunch()`.**

`WealthAppSessionController.prepareLaunch()` calls **only Path B**. Path A is never called through the new bootstrap chain. Path A is the only path that sets `tradingLifecycleArmed = true`. Path B never sets this flag.

**Impact:**  
- `tradingLifecycleArmed` never becomes `true` via the new boot path  
- `WealthPortfolioLifecycleHelper` retries for 30 seconds then gives up (logs `tradingLifecycleArmed never became true`)  
- Activity admission never runs on startup  
- If ContentView still calls `runActivationSequence()` directly, **both paths run simultaneously**, causing duplicate scans, duplicate timer scheduling, and data races on `rankedAssets`  

---

## CRITICAL BUG #3 — Core Scan Functions Are Empty Stubs

**File:** `WealthEngineStore+Refresh.swift`  
**Lines:** 102–136  
**Functions:** `performUniverseScan()`, `performResearchFeeds()`, `performIBKRSync()`

```swift
@MainActor
func performUniverseScan() {
    // Implemented in WealthCore.swift (existing engine logic).
}

@MainActor
func performResearchFeeds() {
    // Appends research-feed intel to ranked cards.
}

@MainActor
func performIBKRSync() {
    // Price-only sync via IBKR bridge.
}
```

**Why Critical:**  
Swift extensions cannot override methods in other extensions. `WealthCore.swift` cannot re-implement these without a duplicate-definition compiler error. These three methods are called by every refresh path (soft refresh, deep refresh, IBKR sync) and are completely empty as committed.

**Impact:**  
- Universe never reloads via the timer refresh path  
- Research feeds never append to ranked cards  
- IBKR price sync never runs  
- Every 9/19/29-minute IBKR timer tick does nothing  
- Universe data is only ever restored from cache and never refreshed in-cycle  

---

## CRITICAL BUG #4 — `Task.detached` Does Not Move Work Off Main Thread

**File:** `WealthEngineStore+Refresh.swift`  
**Lines:** 48–74  
**Functions:** `runUniverseScan()`, `runAIScan()`, `runMarketRanking()`, `runResearchFeeds()`

```swift
func runUniverseScan() async {
    await Task.detached(priority: .userInitiated) { [weak self] in
        await self?.performUniverseScan()  // ← @MainActor — hops BACK to main thread
    }.value
}
```

**Why Critical:**  
`performUniverseScan()` is annotated `@MainActor`. When `Task.detached` calls it, Swift's concurrency runtime hops to the `@MainActor` executor to run it. The `Task.detached` wrapper provides **no off-thread execution** — all work still runs on the main actor. The file header comment "executed on background threads so the UI is never blocked" is incorrect.

**Impact:**  
- Universe scan, AI scan, market ranking, and research feeds all execute on the main thread  
- UI freezes during scan phases  
- The primary stated goal of the file (background scanning) is not achieved  

---

## CRITICAL BUG #5 — `earningsRisk` and `macroRisk` Use Wrong Source Fields

**File:** `Opportunity+CardStateMachine.swift`  
**Lines:** 71–88  
**Properties:** `earningsRisk`, `macroRisk`

```swift
var earningsRisk: Int {
    // ⚠️ PLACEHOLDER — WILL produce incorrect safeguard decisions in production
    Int((risk * 100).rounded())   // generic `risk` float, NOT earnings-specific
}

var macroRisk: Int {
    // ⚠️ PLACEHOLDER — WILL produce incorrect safeguard decisions in production
    Int(((1.0 - probability) * 100).rounded())  // inverted probability ≠ macro risk
}
```

**Why Critical:**  
The code itself is annotated with warnings that these derivations are semantically incorrect and will produce wrong safeguard decisions. `earningsRisk` uses the generic `risk` float (which is not an earnings-calendar or event-specific field). `macroRisk` uses `1 - probability`, which has no relationship to macroeconomic risk.

**Impact:**  
- Safeguard gate in `materializeMarketCandidates()` incorrectly accepts/rejects cards based on wrong risk metrics  
- Cards with high probability (good) are penalized with high `macroRisk` (1 - high_probability = low macro risk... wait, a high-probability card has `probability` near 1.0, so `macroRisk = Int(0.0 * 100) = 0` — that is LOW risk). Cards with low probability get `macroRisk` near 100. This inverts the intended behavior: low-confidence cards are incorrectly treated as high macro-risk  
- Safeguard decisions for **every card in every scan cycle** are wrong in production  

---

## CRITICAL BUG #6 — `tradingLifecycleArmed` Property Location Conflict

**Files:**  
- `WealthEngineStore+Activation.swift:101` — sets `self.tradingLifecycleArmed = true` on `WealthEngineStore`  
- `WealthPortfolioStore+Lifecycle.swift:38` — reads `tradingLifecycleArmed` as `self.tradingLifecycleArmed` on `WealthPortfolioStore`  
- `WealthPortfolioStore+LifecycleHelpers.swift:55,86` — reads `WealthPortfolioStore.shared.tradingLifecycleArmed`

**Why Critical:**  
`tradingLifecycleArmed` is set on `WealthEngineStore` instance but read from `WealthPortfolioStore` instance in two separate files. If `WealthPortfolioStore` does not have this property defined in `WealthCore.swift`, all three references are compile errors. Even if both stores have the property, they are **two separate flags** — setting one never sets the other, so the lifecycle check in `WealthPortfolioLifecycleHelper` will never see the armed state even after startup completes.

**Impact:**  
- Activity admission gate check reads wrong store  
- `rerunActivityAdmissionAfterStartup()` guard always fails  
- Activity reconciliation never runs post-startup  

---

## CRITICAL BUG #7 — `reconcileActivityAdmissions()` Not Defined in Any Committed File

**File:** `WealthPortfolioStore+Lifecycle.swift`  
**Line:** 54  
**Function:** `rerunActivityAdmissionAfterStartup()`

```swift
reconcileActivityAdmissions()   // ← no definition in any committed Swift file
```

**Why Critical:**  
`reconcileActivityAdmissions()` is assumed to exist in `WealthCore.swift`, but `WealthCore.swift` is not committed to the repository and cannot be verified. If this method does not exist on `WealthPortfolioStore` in `WealthCore.swift`, this is a **compile error** that prevents the app from building.

**Impact:**  
- Build failure (if unresolved)  
- Even if resolved, Activity reconciliation still cannot run due to Bug #6  

---

## CRITICAL BUG #8 — `endDashboardRefreshFreeze()` Not Defined in Any Committed File

**File:** `WealthEngineStore+Activation.swift`  
**Line:** 61  
**Function:** `runActivationSequence()` defer block

```swift
defer {
    if Task.isCancelled {
        pendingRefreshPayload = nil
        startupSequencePhase = .idle
        endDashboardRefreshFreeze()   // ← no definition in any committed Swift file
    }
    ...
}
```

**Why Critical:**  
`endDashboardRefreshFreeze()` is called in the cancellation cleanup path but is not defined in `WealthEngineStore+Dashboard.swift` (which defines `endDashboardRefresh()`, not `endDashboardRefreshFreeze()`). If this method does not exist in `WealthCore.swift`, it is a **compile error**.

**Impact:**  
- Build failure (if unresolved)  
- Dashboard loading state is never cleared on activation cancellation, leaving a perpetual loading spinner  

---

## CRITICAL BUG #9 — `scheduledCheckpointTimer` and `preScanBurstTimer` Referenced Under New Timer Architecture

**File:** `WealthEngineStore+Activation.swift`  
**Lines:** 43–50  
**Function:** `runActivationSequence()`

```swift
scheduledCheckpointTimer?.invalidate()
preScanBurstTimer?.invalidate()
scheduledCheckpointTimer = nil
preScanBurstTimer = nil
```

**Why Critical:**  
Under the timer architecture refactored in `WealthEngineStore+Timers.swift`, only `softTimer` and `heavyTimer` are stored (plus the `timerHolder` for IBKR and extra soft timers). The memory notes confirm `preScanBurstTimer` was removed. `scheduledCheckpointTimer` may or may not still exist in `WealthCore.swift`. If either property is absent from `WealthCore.swift`, this is a **compile error**.

**Impact:**  
- Build failure (if properties removed)  
- If present but unused, invalidation calls are no-ops and timers leak  

---

## CRITICAL BUG #10 — `WealthBrainStore.bias()` Never Called

**File:** `WealthBrainStore.swift`  
**Lines:** 53, 74–77  
**Functions:** `ingest()`, `bias()`

```swift
func ingest(...) {
    learn()   // ← called
    // bias() is NEVER called
}

func bias() {
    // Implemented in WealthCore.swift (existing engine logic).
}
```

**Why Critical:**  
`ingest()` calls `learn()` to update the brain's internal model from scan observations, but `bias()` — which applies the learned bias back to opportunity rankings — is never called anywhere in the committed codebase.

**Impact:**  
- Brain learns (accumulates state) but the learned bias is never applied to card scores  
- AI scoring is unaffected by the brain's learning cycles  
- Brain integration added in PR #27 is non-functional for the scoring feedback path  

---

## CRITICAL BUG #11 — IBKR Market Data Subscriptions Not Tracked

**File:** `WealthIBKRBridge.swift`  
**Lines:** 44–69  
**Function:** `subscribeMarketData(contract:)`

```swift
func subscribeMarketData(contract: WealthIBKRContract) -> Int {
    let reqID = nextReqID()
    send([...])
    return reqID
    // ← subscriptions[reqID] is never set
}
```

**Why Critical:**  
`subscriptions: [Int: Subscription]` is declared as the tracking dictionary for active subscriptions, but `subscribeMarketData()` never writes to it. The subscription is sent to TWS but not recorded.

**Impact:**  
- `subscriptions` is always empty  
- No programmatic way to list, cancel, or audit active market-data subscriptions  
- On disconnect/reconnect, outstanding subscriptions cannot be automatically cancelled or re-subscribed  
- TWS will continue streaming tick data for orphaned requests  

---

## CRITICAL BUG #12 — `performFullRecovery()` Does Not Restart Startup Sequence

**File:** `WealthEngineRuntimeRecovery.swift`  
**Lines:** 109–122  
**Function:** `performFullRecovery(reason:)`

```swift
func performFullRecovery(reason: String) {
    WealthDownstreamRebuildOrchestrator.shared.cancelRebuild()
    WealthSessionUnlockController.shared.cancelSessionResume()
    WealthReadyStateGate.shared.reset()
    WealthEngineStore.shared.recoverFromFailedRefresh(reason: reason)
    // ← WealthEngineStartupController.shared.cancelStartupSequence() NOT called
    // ← beginStartupSequence() NOT called
}
```

**Why Critical:**  
After `performFullRecovery()`, `WealthEngineStartupController.isStartupComplete` remains `true`. No new startup sequence is queued. The engine is in a partially cleared state (flags reset, cache restored) but without fresh scan data or a running startup pipeline.

Compare to `resetToFactoryDefaults()` (in `WealthEngineStore+Recovery.swift:50`) which correctly calls `WealthEngineStartupController.shared.cancelStartupSequence()`. Full recovery is incomplete.

**Impact:**  
- After a critical failure and full recovery, the engine never re-scans  
- Data remains stale indefinitely until the user force-quits and relaunches  
- Recovery path intended to fix crashes leaves the engine in a broken state  

---

## CRITICAL BUG #13 — `restoreCache()` Blocks Main Thread on Recovery Path

**File:** `WealthEngineStore+Cache.swift`  
**Lines:** 65–76  
**Function:** `restoreCache()`

```swift
func restoreCache() {
    ...
    restoreRankedAssetsFromFile()     // synchronous Data(contentsOf:) + JSONDecoder
    restoreScannedSignalsFromFile()   // synchronous
    restoreHoldingsFromFile()         // synchronous
}
```

**Why Critical:**  
`restoreCache()` is called from `recoverFromFailedRefresh()` (in `WealthEngineStore+Recovery.swift:32`). `recoverFromFailedRefresh()` is called from `WealthEngineRuntimeRecovery.performFullRecovery()`, which runs on `@MainActor`. Decoding up to 128,000 `Opportunity` records synchronously on the main thread will freeze the UI for several seconds.

The background cache path (`restoreCacheInBackground()` in `WealthEngineStore+BackgroundCache.swift`) exists precisely to fix this problem but is not used in the recovery flow.

**Impact:**  
- UI freezes for multiple seconds during recovery  
- Defeats the stated goal of non-blocking startup/recovery  

---

## CRITICAL BUG #14 — Potential Infinite Rebuild Loop (Cache Sanity + Stale Detector)

**Files:**  
- `WealthDownstreamCacheSanity.swift:42–53` — observer on `.wealthEngineDidBecomeReady`  
- `WealthStaleCacheDetector.swift:97–123` — `checkAndRebuildIfNeeded()`  
- `WealthNewComponentsBootstrap.swift:65–74` — observer on `.wealthEngineDidBecomeReady`  

**Why Critical:**  
The sequence of events after each successful rebuild:

1. `WealthDownstreamRebuildOrchestrator` completes → calls `WealthReadyStateGate.markDownstreamRebuildComplete()`  
2. `WealthReadyStateGate` posts `.wealthEngineDidBecomeReady`  
3. **Two** observers fire in undefined order:  
   - `WealthDownstreamCacheSanity.validatePersistedDownstreamState()` — checks file freshness  
   - `WealthNewComponentsBootstrap.runPostReadyPipeline()` — saves files then calls `evaluateCandidates()`  

If `WealthDownstreamCacheSanity`'s observer fires **before** `WealthNewComponentsBootstrap` saves the cache files, the files don't exist yet → `isAILiveResultsFresh = false`, `isMarketSnapshotFresh = false`, `isActivityStateFresh = false` → `checkAndRebuildIfNeeded()` triggers another rebuild → rebuild completes → `.wealthEngineDidBecomeReady` fires again → loop.

Additionally, `WealthStaleCacheDetector.checkAndRebuildIfNeeded()` **always** calls `triggerRebuild()` even when caches are fresh (line 122: `triggerRebuild(reason: "session-resume")`), ensuring a rebuild fires on every app foreground event regardless of data freshness.

**Impact:**  
- Potential rebuild loop after each startup  
- Constant redundant AI scan + market ranking runs on every unlock  
- Battery drain, CPU spike, and UI stutter on every app foreground  

---

## CRITICAL BUG #15 — `WealthEngineScanScheduler` Not Reset Between Cycles

**File:** `WealthEngineScanScheduler.swift`  
**Line:** 70–91  
**Function:** `markPhaseComplete(_:)`

```swift
func markPhaseComplete(_ phase: ScanPhase) {
    guard !completedPhases.contains(phase) else { return }  // duplicate calls ignored
    completedPhases.insert(phase)
    ...
}
```

**Why Critical:**  
`WealthEngineScanScheduler.reset()` is called only from `WealthEngineRuntimeRecovery.runStartupIntegrityCheck()` at the start of each startup. But `markPhaseComplete()` is also called from `WealthEngineRefresh+LifecyclePublishing.swift` during timer-driven scan cycles (soft/deep refreshes). After all 5 phases complete during startup, `completedPhases` is full. When the 10/20/30-minute timers trigger `runUniverseScanWithProgress()`, `markPhaseComplete(.universeScan)` returns immediately (duplicate guard) without updating progress or posting notifications.

**Impact:**  
- After startup completes, scan progress notifications stop firing  
- AI Live coordinator's `hasReachedAILiveGate` check in subsequent timer cycles reads the startup-time progress (1.0 = 100%), which is stale and misleading  
- No progress tracking for recurring timer scans  

---

## SERIOUS BUG #16 — `WealthIBKRBridge` Runs Network Callbacks on Main Queue

**File:** `WealthIBKRBridge.swift`  
**Line:** 96  
**Function:** `connect(host:port:)`

```swift
conn.start(queue: .main)
```

**Why Critical:**  
`NWConnection.start(queue:)` uses the given queue for all state-update and receive callbacks. Using `.main` means all raw TCP receive events process on the main thread. Even though handlers hop to `@MainActor` via `Task`, the receive loop (`startReceiving()`) recurses synchronously on the main queue before posting to `@MainActor`.

**Impact:**  
- High-frequency tick data (100+ symbols) will cause main thread saturation  
- UI jank/dropped frames during active market hours  
- `startReceiving()` recursion on main queue for every received packet  

---

## SERIOUS BUG #17 — `WealthStaleCacheDetector` Comment Parsing Error (Broken MARK)

**File:** `WealthStaleCacheDetector.swift`  
**Line:** 46

```swift
let backgroundFreshnessThreshold: TimeInterval = 30 * 60    // MARK: - Public API
```

**Why Critical:**  
The `// MARK: - Public API` separator is concatenated on the same line as a stored property. It is treated as an inline comment on the property, not a section separator. The public API section has no separator, breaking file navigation and code organization. This is a minor formatting issue but indicates the file structure is incorrect.

---

## SERIOUS BUG #18 — `nonisolated(unsafe)` Timer Holder Bypasses Concurrency Safety

**File:** `WealthEngineStore+Timers.swift`  
**Line:** 31  

```swift
private nonisolated(unsafe) let timerHolder = WealthTimerHolder()
```

**Why Critical:**  
`nonisolated(unsafe)` suppresses Swift concurrency isolation checking for `timerHolder`. `WealthTimerHolder` holds `Timer` arrays that are mutated in `invalidateTimers()` and `scheduleRecurringTimers()` — both called from `@MainActor` context. However, `nonisolated(unsafe)` means the compiler will not catch any future accidental access from a non-main-actor context.

**Impact:**  
- No compiler-enforced protection against off-actor access  
- Any future code that accesses `timerHolder` from a background task will silently create a data race  

---

## ARCHITECTURAL ISSUE #19 — `runActivationSequence()` References Properties Unknown at Compile Time

**File:** `WealthEngineStore+Activation.swift`  
**Lines:** 43–50, 67–68, 98–103  
**Function:** `runActivationSequence()`

The following properties are referenced in this extension but must be defined in `WealthCore.swift` (not committed):

| Property/Method | Line | Status |
|---|---|---|
| `scheduledCheckpointTimer` | 43, 47 | Unknown — may be removed under new timer architecture |
| `preScanBurstTimer` | 46, 50 | Unknown — memory suggests this was removed |
| `downstreamRecoveryPending` | 52 | Unknown |
| `startupSequencePhase` | 67 | Unknown |
| `phoneStartupScanDelayNanoseconds` | 68 | Unknown |
| `lockedCheckpointProgress` | 100 | Unknown |
| `tradingLifecycleArmed` | 101 | Conflicts with WealthPortfolioStore (Bug #6) |
| `endDashboardRefreshFreeze()` | 61 | Not defined anywhere in committed files |
| `runStartupActivationScan()` | 89 | Not defined anywhere in committed files |
| `runStartupMarketWarmup()` | 93 | Not defined anywhere in committed files |

**Impact:**  
Any property or method missing from `WealthCore.swift` causes a **build failure**. The extension cannot be tested or compiled in isolation.

---

## ARCHITECTURAL ISSUE #20 — `WealthMarketUniverseStore` / `WealthAllCardsStore` Not Committed

**Files referenced but not committed:**
- `WealthMarketUniverseStore` — used in `WealthEngineStore+Activation.swift:80–86`, `WealthEngineStore+UniverseBlueprints.swift:57–61`
- `WealthAllCardsStore` — used in `WealthEngineStore+Materialization.swift:100–106`, `WealthMarketExecutionAudit.swift:146`
- `WealthPortfolioStore` — used in `WealthPortfolioStore+Lifecycle.swift`, `WealthPortfolioStore+LifecycleHelpers.swift`
- `WealthEventLogStore` — used in virtually every file
- `WealthResearchFeedEngine`, `WealthResearchIntelStore`, `WealthResearchCard` — referenced in memory notes but not in committed files

**Impact:**  
- All committed Swift files are extensions/additions on types that live only in `WealthCore.swift` (not in git)  
- The committed code cannot be built, tested, or validated without `WealthCore.swift`  
- Any refactoring of `WealthCore.swift` types can silently break all committed extensions  

---

## Summary Table — Critical Issues by Priority

| # | File | Line(s) | Function | Issue | Severity |
|---|---|---|---|---|---|
| 1 | `WealthEngineStore+Materialization.swift` | 98–106 | `materializeMarketCandidates()` | `ranked` computed but never stored — all cards stay rank 0 — Activity always empty | 🔴 CRITICAL |
| 2 | `WealthEngineStore+Activation.swift` vs `WealthEngineStartupController.swift` | All | `runActivationSequence()` / `beginStartupSequence()` | Two competing startup paths — `tradingLifecycleArmed` never set via new path | 🔴 CRITICAL |
| 3 | `WealthEngineStore+Refresh.swift` | 102–136 | `performUniverseScan()`, `performResearchFeeds()`, `performIBKRSync()` | Core scan functions are empty stubs — no data ever loads | 🔴 CRITICAL |
| 4 | `WealthEngineStore+Refresh.swift` | 48–74 | `runUniverseScan()` etc. | `Task.detached` wrapping `@MainActor` methods — work still runs on main thread | 🔴 CRITICAL |
| 5 | `Opportunity+CardStateMachine.swift` | 71–88 | `earningsRisk`, `macroRisk` | Confirmed placeholder — wrong source fields — safeguard gate decisions are incorrect | 🔴 CRITICAL |
| 6 | `WealthPortfolioStore+Lifecycle.swift` / `LifecycleHelpers.swift` | 38, 55, 86 | `rerunActivityAdmissionAfterStartup()` | `tradingLifecycleArmed` read from wrong store (WealthPortfolioStore vs WealthEngineStore) | 🔴 CRITICAL |
| 7 | `WealthPortfolioStore+Lifecycle.swift` | 54 | `rerunActivityAdmissionAfterStartup()` | `reconcileActivityAdmissions()` not defined in any committed file | 🔴 CRITICAL |
| 8 | `WealthEngineStore+Activation.swift` | 61 | `runActivationSequence()` defer | `endDashboardRefreshFreeze()` not defined in any committed file | 🔴 CRITICAL |
| 9 | `WealthEngineStore+Activation.swift` | 43–50 | `runActivationSequence()` | `scheduledCheckpointTimer`, `preScanBurstTimer` may not exist under new timer arch | 🔴 CRITICAL |
| 10 | `WealthBrainStore.swift` | 53, 74–77 | `ingest()`, `bias()` | `bias()` never called — brain learning never influences AI scores | 🔴 CRITICAL |
| 11 | `WealthIBKRBridge.swift` | 44–69 | `subscribeMarketData(contract:)` | Subscriptions never added to `subscriptions` dict — tracking broken | 🔴 CRITICAL |
| 12 | `WealthEngineRuntimeRecovery.swift` | 109–122 | `performFullRecovery(reason:)` | Does not restart startup sequence after recovery — engine left in limbo | 🔴 CRITICAL |
| 13 | `WealthEngineStore+Cache.swift` | 65–76 | `restoreCache()` | Synchronous main-thread JSON decode of 128k cards in recovery path | 🔴 CRITICAL |
| 14 | `WealthDownstreamCacheSanity.swift` + `WealthStaleCacheDetector.swift` | 42–53, 97–123 | `validatePersistedDownstreamState()`, `checkAndRebuildIfNeeded()` | Race condition between cache save and freshness check → potential infinite rebuild loop | 🔴 CRITICAL |
| 15 | `WealthEngineScanScheduler.swift` | 70–91 | `markPhaseComplete(_:)` | Scheduler not reset between timer cycles — progress notifications stop after startup | 🔴 CRITICAL |
| 16 | `WealthIBKRBridge.swift` | 96 | `connect(host:port:)` | NWConnection on main queue — high-frequency tick data saturates main thread | 🟠 SERIOUS |
| 17 | `WealthStaleCacheDetector.swift` | 46 | Property declaration | `// MARK: - Public API` concatenated on property line — broken code structure | 🟡 SERIOUS |
| 18 | `WealthEngineStore+Timers.swift` | 31 | Module-level var | `nonisolated(unsafe)` bypasses concurrency safety for timer holder | 🟠 SERIOUS |
| 19 | `WealthEngineStore+Activation.swift` | Various | `runActivationSequence()` | 10+ properties/methods referenced that only exist in non-committed `WealthCore.swift` | 🟠 SERIOUS |
| 20 | Multiple files | N/A | N/A | `WealthMarketUniverseStore`, `WealthPortfolioStore`, `WealthEventLogStore`, `WealthAllCardsStore` not committed — codebase cannot be fully built or validated | 🟠 ARCHITECTURAL |

---

*Report generated via full static audit. No code was added, removed, or changed.*
