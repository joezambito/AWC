# AWC Swift Full Audit Report
**Date:** 2026-04-05  
**Scope:** All 34 Swift files in `Wealth Creation/`  
**Constraint:** Report only — no code changes, no deletions, no additions

---

## Summary Table

| # | Severity | File | Function / Location | Issue |
|---|----------|------|---------------------|-------|
| 1 | 🔴 CRITICAL | `WealthEngineStore+Materialization.swift` | `materializeMarketCandidates()` | `ranked` result discarded — never stored |
| 2 | 🔴 CRITICAL | `WealthEngineStore+Activation.swift` | `runActivationSequence()` | References undefined stored properties — will not compile |
| 3 | 🔴 CRITICAL | `WealthEngineStartupController.swift` | `runStartupSequence()` | `wealthEngineDidBecomeReady` never fires after startup |
| 4 | 🔴 CRITICAL | `WealthEngineStore+Refresh.swift` | `performResearchFeeds()`, `performIBKRSync()` | Both are empty stubs — core refresh work never executes |
| 5 | 🔴 CRITICAL | `WealthEngineStore+Activation.swift` | `runActivationSequence()` | Only partial timer teardown — `timerHolder` IBKR/extra-soft timers left running |
| 6 | 🔴 CRITICAL | — | App launch | Two independent startup paths (`runActivationSequence` vs `WealthEngineStartupController`) — double-bootstrap risk |
| 7 | 🟠 HIGH | `WealthEngineStore+Cache.swift` | `restoreCache()` | Comment says timestamps-only but actually decodes large JSON arrays on main thread |
| 8 | 🟠 HIGH | `WealthEngineStore+Refresh.swift` | `runUniverseScan()` et al. | `Task.detached` wraps `@MainActor` methods — always hops back to main; no off-thread benefit |
| 9 | 🟠 HIGH | `WealthBrainStore.swift` | `ingest()` | `bias()` is never called — brain learns but never adjusts scoring |
| 10 | 🟠 HIGH | `WealthIBKRBridge.swift` | `handleApiMessage(data:)` | Empty stub — all IBKR API responses silently dropped |
| 11 | 🟠 HIGH | `WealthEngineStore+Refresh.swift` | `performAIScan()` | `activationStage` conflates startup stage with timer cycle stage |
| 12 | 🟠 HIGH | `WealthEngineStore+Activation.swift` | `runActivationSequence()` | `endDashboardRefreshFreeze()` called but not defined in any committed file |
| 13 | 🟡 MEDIUM | `WealthEngineScanScheduler.swift` | Progress gate comment | Comment says "2 of 4 data phases → 0.5" — wrong; actually needs 3 of 5 phases (60%) |
| 14 | 🟡 MEDIUM | `WealthStaleCacheDetector.swift` | Line ~58 | `// MARK:` comment appended inline to property definition — breaks MARK navigation |
| 15 | 🟡 MEDIUM | `WealthPortfolioStore+LifecycleHelpers.swift` | `scheduleArmedRetry()` | Old `retryTask` never cancelled before replacement — multiple retry tasks can pile up |
| 16 | 🟡 MEDIUM | `WealthEngineStore+Materialization.swift` | `materializeMarketCandidates()` | `isMarketMaterializationInFlight = false` set explicitly AND inside `defer` — redundant |
| 17 | 🟡 MEDIUM | `WealthEngineStore+Activation.swift` | `runActivationSequence()` | `activationStage = 0` set to 0 on completion — resets to stage 0 instead of a "done" sentinel |
| 18 | 🟡 MEDIUM | `Opportunity+CardStateMachine.swift` | `earningsRisk`, `macroRisk` | Placeholder derivations from `risk` / `probability` — semantically incorrect for safeguard gate |
| 19 | 🟡 MEDIUM | `WealthEngineStore+Recovery.swift` | `recoverFromFailedRefresh()` | Calls `restoreCache()` (main-thread JSON decode) from a recovery path that may run during a refresh cycle |
| 20 | 🔵 LOW | `WealthIBKRBridge+Send.swift` | `subscribeMarketData()` | Message fields for contract include hard-coded empty strings — conId/exchange/currency not validated |
| 21 | 🔵 LOW | `WealthTimerHolder` | File-private class | `nonisolated(unsafe)` bypasses Swift 6 actor isolation — potential data race if accessed off main actor |

---

## Detailed Findings

---

### 🔴 CRITICAL-1 — Ranked Results Discarded in `materializeMarketCandidates()`
**File:** `WealthEngineStore+Materialization.swift`  
**Function:** `materializeMarketCandidates()`  
**Lines:** ~78–100

**What's wrong:**
```swift
let ranked = assignMarketRanks(to: recheckPassed)

WealthAllCardsStore.shared.sync(
    opportunities: rankedAssets,   // ← original universe, NOT `ranked`
    ...
)
```
`assignMarketRanks()` computes market ranks and returns a new `[Opportunity]` array. The result is stored in `ranked` but:
1. **Never assigned back to `rankedAssets`** — so `rankedAssets` retains unranked data after every materialization pass.
2. **`WealthAllCardsStore.shared.sync()` receives `rankedAssets`** (the entire pre-ranking universe), not `ranked` (the top-100 ranked candidates).

**Why it's critical:**  
Every downstream consumer that reads `rankedAssets` or checks `opportunity.rank` after `materializeMarketCandidates()` returns sees unranked data. `WealthAILiveCoordinator.evaluateCandidates()` filters `engine.rankedAssets.filter { $0.rank > 0 }` — because `rank` is never updated, this filter always returns zero cards. AI Live is always empty.

**Impact:** AI Live is permanently empty. Activity queue is permanently empty.

---

### 🔴 CRITICAL-2 — `runActivationSequence()` References Undefined Stored Properties
**File:** `WealthEngineStore+Activation.swift`  
**Function:** `runActivationSequence()`  
**Lines:** ~42–115

**What's wrong:**  
The function references the following identifiers that are **not defined in any committed file**:

| Identifier | Type | Used For |
|---|---|---|
| `scheduledCheckpointTimer` | `Timer?` | Invalidated at startup |
| `preScanBurstTimer` | `Timer?` | Invalidated at startup |
| `downstreamRecoveryPending` | `Bool` | Set to `true` before scan |
| `startupSequencePhase` | enum/type | Set to `.waitingToScan`, `.idle` |
| `phoneStartupScanDelayNanoseconds` | `UInt64` | Sleep duration |
| `lockedCheckpointProgress` | `Int` | Set on completion |
| `Self.lockedCheckpointCount` | `Int` (static) | Used as value for above |
| `tradingLifecycleArmed` | `Bool` | Set to `true` on completion |
| `endDashboardRefreshFreeze()` | method | Called in defer on cancellation |
| `runStartupActivationScan()` | method | Performs AI brain scan |
| `runStartupMarketWarmup()` | method | Performs market warmup |

These are presumably defined in `WealthCore.swift` which is **not committed to the repository**. The extension will fail to compile without the base class definition.

**Why it's critical:** This file will not compile. The entire activation sequence path is broken.

---

### 🔴 CRITICAL-3 — `wealthEngineDidBecomeReady` Never Posts After Initial Startup
**File:** `WealthEngineStartupController.swift`  
**Function:** `runStartupSequence()`  
**Lines:** ~88–116

**What's wrong:**  
After `runStartupSequence()` completes it calls `engine.rescheduleTimers()` and logs a message. It does **NOT**:
- Call `WealthDownstreamRebuildOrchestrator.shared.triggerRebuild()`
- Call `WealthReadyStateGate.shared.markDownstreamRebuildComplete()`

The notification `Notification.Name.wealthEngineDidBecomeReady` is posted only from `WealthReadyStateGate.markDownstreamRebuildComplete()`, which is called only from `WealthDownstreamRebuildOrchestrator.performDownstreamRebuild()`.

`triggerRebuild()` is only called from:
1. `WealthStaleCacheDetector.checkAndRebuildIfNeeded()` → called by `WealthSessionUnlockController.handleSessionResume()` → called ONLY on foreground activation after startup is already complete.
2. `WealthEngineRuntimeRecovery.performFullRecovery()` → called only on explicit recovery.

**Chain of consequence:**
1. App launches → startup sequence completes → `isStartupComplete = true`
2. Timers rescheduled
3. `wealthEngineDidBecomeReady` is **never posted**
4. `WealthDownstreamCacheSanity.validatePersistedDownstreamState()` never fires (its observer never triggers)
5. `WealthNewComponentsBootstrap.runPostReadyPipeline()` never runs
6. No audits run, no AI Live evaluation, no Activity state persisted
7. On first foreground cycle (app minimize/reopen), `handleBecameActive()` calls `handleSessionResume()` which triggers the rebuild — but only on the **second lifecycle event**, not on first launch.

**Why it's critical:** On first launch, the entire post-ready pipeline (AI Live, audits, cache persistence) never runs. AI Live stays empty until the user backgrounds and reopens the app.

---

### 🔴 CRITICAL-4 — Core Refresh Stubs: `performResearchFeeds()` and `performIBKRSync()`
**File:** `WealthEngineStore+Refresh.swift`  
**Functions:** `performResearchFeeds()`, `performIBKRSync()`  
**Lines:** ~107–115

**What's wrong:**
```swift
@MainActor
func performResearchFeeds() {
    // Appends research-feed intel to ranked cards.
}

@MainActor
func performIBKRSync() {
    // Price-only sync via IBKR bridge.
}
```

Both methods are empty. They are called by:
- `runDeepRefresh()` → `performResearchFeeds()` — 30-minute deep refresh does nothing for research
- `runIBKRPriceSync()` → `performIBKRSync()` — the 9/19/29-minute IBKR timers fire but do zero broker sync

**Why it's critical:**
- IBKR price data is never refreshed. Cards always show stale bid/ask/last prices.
- Research intel is never appended to ranked cards. The research-feed layer is completely non-functional.
- 3 of the 6 scheduled timer intervals (9m, 19m, 29m) fire and do nothing.

---

### 🔴 CRITICAL-5 — Incomplete Timer Teardown in `runActivationSequence()`
**File:** `WealthEngineStore+Activation.swift`  
**Function:** `runActivationSequence()`  
**Lines:** ~46–55

**What's wrong:**
```swift
scheduledCheckpointTimer?.invalidate()
softTimer?.invalidate()
heavyTimer?.invalidate()
preScanBurstTimer?.invalidate()
scheduledCheckpointTimer = nil
softTimer = nil
heavyTimer = nil
preScanBurstTimer = nil
```

This teardown only invalidates `softTimer` and `heavyTimer`. It does **not** invalidate:
- `timerHolder.ibkrTimers` — the three IBKR price-sync timers (9m, 19m, 29m)
- `timerHolder.extraSoftTimers` — the second soft timer (20m)

These timers in `WealthTimerHolder` are only properly invalidated by `invalidateTimers()` defined in `WealthEngineStore+Timers.swift`. The activation sequence bypasses `invalidateTimers()`, leaving the IBKR and second-soft timers alive during the startup scan sequence.

**Why it's critical:** During startup, IBKR price-sync timers and the 20-minute soft refresh timer can fire concurrently with the startup scan sequence, causing concurrent data mutations on `rankedAssets` and other `@Published` properties.

---

### 🔴 CRITICAL-6 — Two Independent Startup Paths Active Simultaneously
**Files:** `WealthEngineStore+Bootstrap.swift`, `WealthEngineStore+Activation.swift`, `WealthEngineStartupController.swift`  

**What's wrong:**  
There are **two separate startup orchestration paths** in the codebase:

**Path A** (`WealthEngineStore+Bootstrap.swift`):
```
bootstrap()
  → WealthAppSessionController.prepareLaunch()
    → WealthNewComponentsBootstrap.activate()
    → WealthEngineStore.restoreCacheInBackground {
         WealthEngineStartupController.beginStartupSequence()
       }
```
Runs: `runUniverseScanWithProgress()` → `runAIScanWithProgress()` → `runMarketRankingWithProgress()` → `runResearchFeedsWithProgress()` → `rescheduleTimers()`

**Path B** (`WealthEngineStore+Activation.swift`):
```
runActivationSequence()
  → Task.detached {
      WealthMarketUniverseStore.prepareCachedSnapshotForStartup()
      runStartupActivationScan()
      runStartupMarketWarmup()
      MainActor.run { rescheduleTimers() }
    }
```
Runs different scan methods and its own timer scheduling.

These are incompatible bootstrap strategies. If both are invoked (directly or by different ContentView observers), timers would be double-scheduled and scans would run in parallel with conflicting state mutations.

**Why it's critical:** If `runActivationSequence()` is still called anywhere in `WealthCore.swift` (the untracked file), it will run simultaneously with Path A, causing timer duplication, concurrent state mutations, and undefined behaviour.

---

### 🟠 HIGH-7 — `restoreCache()` Decodes Large JSON Arrays on Main Thread
**File:** `WealthEngineStore+Cache.swift`  
**Function:** `restoreCache()`  
**Lines:** ~76–86

**What's wrong:**  
The function's own documentation states:
> "Large array decoding is **not** performed here — call `restoreCacheInBackground(completion:)` to avoid blocking the main thread. This synchronous variant restores timestamps only."

But the implementation immediately calls:
```swift
restoreRankedAssetsFromFile()    // JSON decode of 128k cards on main thread
restoreScannedSignalsFromFile()  // JSON decode on main thread
restoreHoldingsFromFile()        // JSON decode on main thread
```

The comment and implementation directly contradict each other.

**Why it's critical:** Called by `recoverFromFailedRefresh()` which runs on the `@MainActor`. Decoding 128k ranked-asset records synchronously on the main thread causes multi-second UI freezes during error recovery — exactly the same freeze that `restoreCacheInBackground()` was designed to prevent.

---

### 🟠 HIGH-8 — `Task.detached` Wrapping `@MainActor` Methods
**File:** `WealthEngineStore+Refresh.swift`  
**Functions:** `runUniverseScan()`, `runAIScan()`, `runMarketRanking()`, `runResearchFeeds()`, `runIBKRPriceSync()`  
**Lines:** ~44–87

**What's wrong:**
```swift
func runUniverseScan() async {
    await Task.detached(priority: .userInitiated) { [weak self] in
        await self?.performUniverseScan()
    }.value
}
```
`performUniverseScan()` (and all the other `perform*` methods) are marked `@MainActor`. Calling them from inside a `Task.detached` block forces the Swift runtime to always schedule a main-actor hop — the detached task immediately surrenders the background thread to wait for the main actor. There is no off-thread execution benefit; the actual work still runs on the main thread.

**Why it's critical:** The architectural goal of keeping heavy scans off the main thread is silently not achieved. Any actual heavy work inside these `@MainActor perform*` methods (which live in `WealthCore.swift`) runs on the main thread, blocking the UI.

---

### 🟠 HIGH-9 — `bias()` Never Called in WealthBrainStore
**File:** `WealthBrainStore.swift`  
**Function:** `ingest()`  
**Lines:** ~55–65

**What's wrong:**
```swift
func ingest(...) {
    learn()   // Called
    // log event
    // bias() is never called
}

func learn() { /* stub */ }
func bias()  { /* stub — but also never invoked */ }
```

`ingest()` calls `learn()` but never calls `bias()`. Even when full implementations of `learn()` and `bias()` are provided in `WealthCore.swift`, the bias application step will never execute, meaning the brain's learned model never influences card scoring.

**Why it's critical:** The entire purpose of the brain is to improve opportunity rankings over time. Without calling `bias()`, the learning loop is permanently half-open: the brain accumulates data but its adjustments are never applied to the pipeline.

---

### 🟠 HIGH-10 — `handleApiMessage()` is Empty in WealthIBKRBridge
**File:** `WealthIBKRBridge.swift`  
**Function:** `handleApiMessage(data:)`  
**Lines:** ~161–163

**What's wrong:**
```swift
private func handleApiMessage(data: Data) {
    // Market data ticks, account updates, etc. parsed here in future extensions
}
```

This method is called for **every** length-prefixed message received after the IBKR handshake completes. All of the following are silently discarded:
- Market data tick messages (bid/ask/last/volume updates)
- Account balance and position updates
- Order status replies
- Error messages from TWS

**Why it's critical:** After `connect()` + `sendStartAPI()` succeeds and `apiReady = true`, the bridge receives live data but throws it all away. `WealthIBKRBridge+Send.swift` even defines `subscribeMarketData(contract:)` and sends subscription requests, but no quote will ever reach the app because the response handler is empty. `performIBKRSync()` (already a stub) would also depend on this.

---

### 🟠 HIGH-11 — `activationStage` Conflates Startup Stage with Timer Cycle Stage
**File:** `WealthEngineStore+Refresh.swift`  
**Function:** `performAIScan()`, `WealthEngineStore+Timers.swift` timer callbacks  

**What's wrong:**  
In `performAIScan()`:
```swift
WealthBrainStore.shared.ingest(
    ...
    stage: activationStage,
    stageTotal: 6,
    ...
)
```

`activationStage` is set by the timer callbacks (stages 0–5 per the 30-minute cycle) AND by the activation sequence (`activationStage = 0` on completion). The field is used both as a **startup progress indicator** (0 = first IBKR sync, 5 = deep refresh) and as a **completion sentinel** (set to 0 after startup finishes). These two usages are semantically incompatible — stage 0 means both "IBKR sync firing" and "startup complete."

**Why it's critical:** `WealthBrainStore.ingest()` receives incorrect stage information, making its `cycleComplete` and `stage` context unreliable for learning.

---

### 🟠 HIGH-12 — `endDashboardRefreshFreeze()` Called But Not Defined
**File:** `WealthEngineStore+Activation.swift`  
**Function:** `runActivationSequence()`, `defer` block  
**Lines:** ~64

**What's wrong:**
```swift
defer {
    if Task.isCancelled {
        pendingRefreshPayload = nil
        startupSequencePhase = .idle
        endDashboardRefreshFreeze()    // ← method not in any committed file
    }
    activationTask = nil
}
```

`endDashboardRefreshFreeze()` is not defined in any of the 34 committed Swift files. It presumably lives in `WealthCore.swift`.

**Why it's critical:** This will fail to compile. On task cancellation, the defer block cannot execute, leaving the dashboard in a frozen state with no recovery path.

---

### 🟡 MEDIUM-13 — Scan Progress Gate Comment Is Wrong
**File:** `WealthEngineScanScheduler.swift`  
**Lines:** ~54–57

**What's wrong:**
```swift
/// The minimum scan progress required before AI Live is allowed to
/// promote Market candidates.  Requires at least universe scan + AI scan
/// complete (phases 1 and 2 of 4 data phases → 0.5).
let minimumProgressForAILive: Double = 0.5
```

There are **5 total phases** (`ScanPhase.allCases.count == 5`), not 4. With 5 phases:
- 2 phases complete = 2/5 = **40%** — does NOT meet the 0.5 threshold
- 3 phases complete = 3/5 = **60%** — meets the threshold

The gate actually opens after `cacheRestore + universeScan + aiScan` (3 phases), not 2 as documented. The comment is misleading.

**Impact:** Consumers who read the comment to understand when AI Live will activate will be incorrect. Any future code that hard-codes "2 phases" based on this documentation will be wrong.

---

### 🟡 MEDIUM-14 — Inline `// MARK:` Comment Breaks Navigation
**File:** `WealthStaleCacheDetector.swift`  
**Lines:** ~57–58

**What's wrong:**
```swift
let backgroundFreshnessThreshold: TimeInterval = 30 * 60    // MARK: - Public API
```

The `// MARK:` directive is appended to the end of a property declaration instead of appearing on its own line. Xcode and other tooling that uses MARK comments for jump-bar navigation will include the `backgroundFreshnessThreshold` declaration in the section titled "Public API", which is incorrect.

---

### 🟡 MEDIUM-15 — `retryTask` Replaced Without Cancelling Previous Task
**File:** `WealthPortfolioStore+LifecycleHelpers.swift`  
**Function:** `scheduleArmedRetry(attemptsRemaining:)`  
**Lines:** ~77–90

**What's wrong:**
```swift
retryTask = Task { [weak self] in
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    guard !Task.isCancelled, let self else { return }
    if WealthPortfolioStore.shared.tradingLifecycleArmed {
        self.triggerAdmissionRerun()
    } else {
        self.scheduleArmedRetry(attemptsRemaining: attemptsRemaining - 1)
    }
}
```

When `scheduleArmedRetry()` recurses, it creates a new `Task` and assigns it to `retryTask`. But the previous `retryTask` is **not cancelled** before replacement. Since the previous task IS the currently-executing task (it just called `scheduleArmedRetry`), its own `isCancelled` check passes, and it continues. But from the next iteration onward, the `retryTask` property no longer holds a reference to the running chain — it references only the latest nested task.

If `cancelSessionResume()` is called and then `scheduleArmedRetry()` runs again (e.g. from a new `wealthEngineDidBecomeReady` notification), two retry chains can run simultaneously, potentially calling `rerunActivityAdmissionAfterStartup()` twice.

---

### 🟡 MEDIUM-16 — Redundant `isMarketMaterializationInFlight = false` in Defer + Early Return
**File:** `WealthEngineStore+Materialization.swift`  
**Function:** `materializeMarketCandidates()`  
**Lines:** ~72–85

**What's wrong:**
```swift
defer { isMarketMaterializationInFlight = false }
// ...
if !recheckPassed.allSatisfy(\.isMarketExecutableCandidate) {
    // ...
    isMarketMaterializationInFlight = false  // ← explicit set
    return                                    // ← defer also fires, sets false again
}
```

The explicit set to `false` before `return` is redundant because the `defer` block fires on every return path including this one. This is not a crash or logic error but creates confusing code that suggests the developer was unsure whether the `defer` would fire.

---

### 🟡 MEDIUM-17 — `activationStage = 0` on Completion Reuses Stage 0 as "Done" Sentinel
**File:** `WealthEngineStore+Activation.swift`  
**Function:** `runActivationSequence()`, `MainActor.run` block  
**Lines:** ~97

**What's wrong:**
```swift
await MainActor.run {
    self.activationStage = 0        // ← "done" — but 0 also means IBKR sync
    self.activationCycleComplete = true
    ...
}
```

After startup completes, `activationStage` is reset to `0`. But `0` is also the stage value assigned by the first IBKR timer (see `WealthEngineStore+Timers.swift`: `makeIBKRTimer(at: TimerInterval.ibkr1, stage: 0)`). This means after startup, every time the 9-minute IBKR timer fires, `activationStage` is set to `0` again — indistinguishable from the "startup complete" state. `WealthBrainStore.ingest()` will see `stage=0` both on startup completion and on every 9-minute IBKR tick.

---

### 🟡 MEDIUM-18 — `earningsRisk` and `macroRisk` Are Placeholder Derivations
**File:** `Opportunity+CardStateMachine.swift`  
**Properties:** `earningsRisk`, `macroRisk`  
**Lines:** ~62–83

**What's wrong:**
```swift
/// ⚠️ PLACEHOLDER – Replace this computed property with the dedicated
/// earnings-risk field from the `Opportunity` model...
var earningsRisk: Int {
    Int((risk * 100).rounded())  // Generic risk, NOT earnings-specific
}

/// ⚠️ PLACEHOLDER – Replace this computed property with a dedicated
/// macro/geopolitical risk field...
var macroRisk: Int {
    Int(((1.0 - probability) * 100).rounded())  // Inverted probability, NOT macro risk
}
```

These are the fields evaluated by the safeguard gate in `materializeMarketCandidates()` with thresholds 70 and 75 respectively. Using generic `risk` and inverted `probability` fields as proxies for earnings-specific and macro-specific risk will cause incorrect safeguard decisions:
- A card with `probability=0.30` would have `macroRisk=70`, **just below the 75 threshold** — likely wrong
- A card with `probability=0.26` would have `macroRisk=74`, **just below 75** — still passes
- A card with `probability=0.25` would have `macroRisk=75`, **rejected** — likely incorrect

**Why it's critical (escalated from MEDIUM):** The safeguard gate is a core safety mechanism. Incorrect risk proxies mean cards that should be rejected pass, and cards that should pass are rejected, corrupting the market ranking.

---

### 🟡 MEDIUM-19 — `recoverFromFailedRefresh()` Calls Synchronous Cache Restore
**File:** `WealthEngineStore+Recovery.swift`  
**Function:** `recoverFromFailedRefresh(reason:)`  
**Lines:** ~27–40

**What's wrong:**
```swift
func recoverFromFailedRefresh(reason: String) {
    isDashboardRefreshInFlight = false
    isMarketMaterializationInFlight = false
    activationTask = nil
    pendingRefreshPayload = nil
    pendingPublishTask = nil
    restoreCache()   // ← synchronous main-thread JSON decode
    // log event
}
```

`restoreCache()` decodes `[Opportunity]`, `[MarketSignal]`, and `[Holding]` from JSON files synchronously on the `@MainActor`. Recovery from a failed refresh will cause a main-thread freeze proportional to the size of the cached data.

---

### 🔵 LOW-20 — `subscribeMarketData()` Sends Hard-Coded Empty Strings
**File:** `WealthIBKRBridge+Send.swift`  
**Function:** `subscribeMarketData(contract:)`  
**Lines:** ~37–57

**What's wrong:**  
The market data subscription message contains several positional empty-string fields that TWS interprets as specific values:
- Position 5 (lastTradeDateOrContractMonth): `""` — TWS may interpret as any expiry
- Position 7 (multiplier): `""` — should be `"0"` for stocks
- Positions 8/9 (tradingClass, primaryExch): `""` — may cause symbol ambiguity
- Position 17 (genericTickList): `""` — sends default ticks only

No validation is performed on `contract.conId`, `contract.symbol`, or `contract.exchange` before sending. A contract with an empty symbol or invalid conId will cause TWS to return error message 321 (Invalid contract), which is silently dropped by `handleApiMessage()`.

---

### 🔵 LOW-21 — `nonisolated(unsafe)` on Timer Holder Bypasses Concurrency Safety
**File:** `WealthEngineStore+Timers.swift`  
**Lines:** ~33–34

**What's wrong:**
```swift
private nonisolated(unsafe) let timerHolder = WealthTimerHolder()
```

`WealthTimerHolder` is a `final class` with mutable `var` properties. Marking the module-level instance `nonisolated(unsafe)` tells the Swift compiler to skip concurrency isolation checks for accesses to this value. While all current call sites are in `@MainActor`-isolated extension methods (safe at runtime), the `unsafe` declaration means future code that accesses `timerHolder` from a non-main-actor context will not get a compile-time warning.

---

## Missing Implementations Summary

| Method | File | Status | Impact |
|--------|------|--------|--------|
| `performUniverseScan()` | `WealthEngineStore+Refresh.swift` | Stub only | Universe never downloaded in this extension |
| `performResearchFeeds()` | `WealthEngineStore+Refresh.swift` | Empty | Research intel never appended |
| `performIBKRSync()` | `WealthEngineStore+Refresh.swift` | Empty | IBKR price sync never runs |
| `handleApiMessage(data:)` | `WealthIBKRBridge.swift` | Empty | All IBKR responses dropped |
| `learn()` | `WealthBrainStore.swift` | Stub (WealthCore.swift) | Brain learning not executed |
| `bias()` | `WealthBrainStore.swift` | Stub — never called | Brain bias never applied |
| `reconcileActivityAdmissions()` | `WealthPortfolioStore+Lifecycle.swift` | Defined in WealthCore.swift | Cannot verify |
| `runStartupActivationScan()` | `WealthEngineStore+Activation.swift` | Defined in WealthCore.swift | Cannot verify |
| `runStartupMarketWarmup()` | `WealthEngineStore+Activation.swift` | Defined in WealthCore.swift | Cannot verify |

---

## State Management Issues

| Property | File | Issue |
|----------|------|-------|
| `activationStage` | Timers + Activation | Stage 0 used for both "IBKR sync" and "startup complete" — ambiguous |
| `isMarketMaterializationInFlight` | Materialization | Redundant reset in defer + early return |
| `isDashboardRefreshInFlight` | Recovery | Never set to `true` by `recoverFromFailedRefresh()` before `restoreCache()` runs |
| `tradingLifecycleArmed` | Activation (WealthCore.swift) | Set inside `Task.detached` background work — may race with `WealthPortfolioLifecycleHelper` polling |
| `rankedAssets` | Materialization | Never updated with ranked results after `materializeMarketCandidates()` |

---

## Threading Issues

| Issue | Files | Details |
|-------|-------|---------|
| Main-thread JSON decode in `restoreCache()` | Cache, Recovery | Up to seconds of UI freeze |
| `Task.detached` wrapping `@MainActor` scans | Refresh | Background scheduling without background execution |
| `nonisolated(unsafe)` timer holder | Timers | Bypasses Swift 6 actor isolation |
| `Timer.scheduledTimer` from `timerHolder` holder accessed without actor isolation guarantee | Timers | Timer holder mutations not formally actor-isolated |
| `retryTask` replaced without cancellation | PortfolioLifecycleHelpers | Concurrent retry chains |

---

## Brain Integration Status (Post-PR #27)

`WealthBrainStore.ingest()` is **correctly called** from `performAIScan()` on every soft and deep refresh. The wiring from PR #27 is in place.

**However, the following issues prevent the brain from functioning:**
1. `learn()` is a stub — no actual learning occurs
2. `bias()` is never called from `ingest()` — even if `bias()` were implemented in `WealthCore.swift`, it would never run
3. `activationStage` passed to `ingest()` is semantically incorrect (stage 0 = both "startup done" and "IBKR sync")
4. `rankedAssets` passed to `ingest()` is unranked (CRITICAL-1) — brain sees unranked data

---

## IBKR Integration Status

| Component | Status |
|-----------|--------|
| TCP connection | ✅ Implemented |
| Handshake (greeting + version parse) | ✅ Implemented |
| `sendStartAPI()` | ✅ Implemented |
| `subscribeMarketData()` | ✅ Implemented |
| `cancelMarketData()` | ✅ Implemented |
| API response parsing | ❌ `handleApiMessage()` is empty |
| Quote delivery to engine | ❌ No quote-to-engine bridge |
| `performIBKRSync()` | ❌ Empty stub |
| Position/account updates | ❌ Not implemented |

---

## File Organization Issues

| Issue | Impact |
|-------|--------|
| `WealthPortfolioStore+Lifecycle.swift` and `WealthPortfolioStore+LifecycleHelpers.swift` are in the same physical file (concatenated) | Two unrelated types in one file; harder to navigate |
| `WealthCore.swift` not committed | Base class for `WealthEngineStore` not in source control; all extensions have unknown compile status |
| Two startup paths in separate files with no shared interface | Path conflict undiscoverable from source alone |

---

## Priority Fix Order

1. **CRITICAL-1** — Store `ranked` back to `rankedAssets` in `materializeMarketCandidates()`
2. **CRITICAL-3** — After startup sequence completes, trigger `WealthDownstreamRebuildOrchestrator`
3. **CRITICAL-4** — Implement `performResearchFeeds()` and `performIBKRSync()`
4. **CRITICAL-2** — Commit `WealthCore.swift` so `runActivationSequence()` can compile
5. **CRITICAL-5** — Replace manual timer teardown with `invalidateTimers()` in activation
6. **CRITICAL-6** — Resolve which startup path is authoritative; remove or disable the other
7. **HIGH-9** — Call `bias()` from `ingest()`
8. **HIGH-10** — Implement `handleApiMessage()` in WealthIBKRBridge
9. **HIGH-7** — Remove file-decode calls from `restoreCache()` (timestamps only, per its own contract)
10. **MEDIUM-18** — Replace `earningsRisk`/`macroRisk` placeholder derivations with real fields
