# AWC Swift Codebase — Cross-Analyzed Audit Report
**Scope:** All 34 Swift source files committed to `Wealth Creation/`  
**Date:** 2026-04-05  
**Method:** Full file-by-file read + cross-file dependency trace  
**Note:** This is a diagnosis/explanation report only. No code changes are suggested.

---

## Table of Contents
1. [Theme A — Incomplete Core Implementations (Empty Stubs)](#theme-a)
2. [Theme B — Competing & Duplicate Startup Paths](#theme-b)
3. [Theme C — Threading / Concurrency Hazards](#theme-c)
4. [Theme D — Placeholder Risk Metrics in the Safeguard Gate](#theme-d)
5. [Theme E — Circular Rebuild Cascade Risk](#theme-e)
6. [Theme F — Scan-Progress Notifications Dead After Startup](#theme-f)
7. [Theme G — Properties Referenced But Not in Git](#theme-g)
8. [Theme H — IBKR Market Data Never Delivered](#theme-h)
9. [Summary Matrix](#summary-matrix)

---

## Theme A — Incomplete Core Implementations (Empty Stubs) {#theme-a}

These are the most operationally critical issues. Multiple scan phases fire on every timer tick but execute no real work because the underlying implementation is an empty stub.

---

### A-1 · `performUniverseScan()` — Always a No-Op

| | |
|---|---|
| **File** | `Wealth Creation/WealthEngineStore+Refresh.swift` |
| **Function** | `performUniverseScan()` |
| **Approx. line** | ~85 |

**Problem**  
The `@MainActor` method `performUniverseScan()` contains only a comment:  
> "Implemented in WealthCore.swift (existing engine logic)."  

The body is completely empty. `WealthCore.swift` is **not committed to git**.

**Called from**  
- `runUniverseScan()` → every soft refresh (10 m, 20 m timers)  
- `runDeepRefresh()` → every deep refresh (30 m timer)  
- `runUniverseScanWithProgress()` → startup sequence  

**Technical Impact**  
Every universe scan phase — on startup AND on every recurring 10-, 20-, and 30-minute timer tick — executes zero logic. `rankedAssets` is never populated from a live scan. The entire downstream pipeline (AI scoring → Market ranking → Activity) operates on stale or empty data indefinitely. The app's primary value proposition (live market opportunity ranking) is structurally broken at the scan layer.

---

### A-2 · `performIBKRSync()` — Price Sync Never Executes

| | |
|---|---|
| **File** | `Wealth Creation/WealthEngineStore+Refresh.swift` |
| **Function** | `performIBKRSync()` |
| **Approx. line** | ~100 |

**Problem**  
The `@MainActor` method `performIBKRSync()` body is empty:  
> "Price-only sync via IBKR bridge."  

**Called from**  
- `runIBKRPriceSync()` → `refresh(mode: .ibkr)` → IBKR timers at 9 m, 19 m, 29 m  

**Technical Impact**  
The three IBKR price-update timers fire on schedule, but no price data is ever fetched or applied to cards. All `WealthBrokerQuote` prices remain stale. IBKR bridge connection and subscription infrastructure (in `WealthIBKRBridge.swift`) is set up correctly, but the bridge to the engine that would apply prices to `rankedAssets` is missing.

---

### A-3 · `performResearchFeeds()` — Deep Refresh Phase Is a No-Op

| | |
|---|---|
| **File** | `Wealth Creation/WealthEngineStore+Refresh.swift` |
| **Function** | `performResearchFeeds()` |
| **Approx. line** | ~92 |

**Problem**  
`performResearchFeeds()` body is empty:  
> "Appends research-feed intel to ranked cards."

**Called from**  
- `runDeepRefresh()` → every 30-minute deep refresh timer  
- `runResearchFeedsWithProgress()` → startup sequence  

**Technical Impact**  
Research intelligence (sector news, analyst ratings, sentiment signals) is never appended to ranked cards. Cards in the Market bucket and AI Live pipeline always have zero research context, affecting score quality and Activity admission decisions. The deep refresh's additional step over a soft refresh provides no value.

---

### A-4 · `WealthBrainStore.learn()` and `bias()` — Brain Never Learns

| | |
|---|---|
| **File** | `Wealth Creation/WealthBrainStore.swift` |
| **Functions** | `learn()`, `bias()` |
| **Approx. lines** | ~65–73 |

**Problem**  
Both `learn()` and `bias()` contain only comments:  
> "Implemented in WealthCore.swift (existing engine logic)."

`learn()` is called from `ingest()` on every AI scan. `bias()` is never called at all — no call site exists anywhere in the committed code.

**Technical Impact**  
The brain accumulates no learning across trading cycles. Every AI scan logs an event (`"Brain Ingest"`) as if learning occurred, but `rankedAssets` AI scores are never adjusted by learned biases. Brain stage tracking (0–5) is set by timer factory methods, giving the appearance of a working brain without any functional scoring effect. This is a silent failure — log entries look healthy but no real adaptation happens.

---

### A-5 · `handleApiMessage(data:)` — IBKR API Messages Silently Discarded

| | |
|---|---|
| **File** | `Wealth Creation/WealthIBKRBridge.swift` |
| **Function** | `handleApiMessage(data:)` |
| **Approx. line** | ~157 |

**Problem**  
After the IBKR handshake completes, every incoming server message is length-decoded and dispatched to `handleApiMessage(data:)`. The method body is empty:  
> "Market data ticks, account updates, etc. parsed here in future extensions."

**Technical Impact**  
All price ticks, account balance updates, order confirmations, error messages, and server keepalives received from TWS/IBKR are silently dropped. The bridge physically connects to TWS, exchanges a valid handshake (`sendGreeting()` → `sendStartAPI()` → subscription), but zero data is ever extracted from any response frame. Market data subscriptions (`subscribeMarketData()`) return a request ID but never deliver a `WealthBrokerQuote` event. This renders the entire IBKR integration non-functional beyond the connection/handshake layer.

---

## Theme B — Competing & Duplicate Startup Paths {#theme-b}

---

### B-1 · Two Parallel Startup Orchestrators for the Same Job

| | |
|---|---|
| **Files** | `WealthEngineStore+Bootstrap.swift`, `WealthEngineStore+Activation.swift`, `WealthEngineStartupController.swift` |
| **Functions** | `bootstrap()`, `runActivationSequence()`, `WealthEngineStartupController.beginStartupSequence()` |

**Problem**  
Two complete, independent startup controllers exist in the committed code:

1. **`WealthEngineStore+Activation.swift` → `runActivationSequence()`**  
   Manages its own `activationTask`, teardown of four timers (`scheduledCheckpointTimer`, `softTimer`, `heavyTimer`, `preScanBurstTimer`), a startup-phase enum (`startupSequencePhase`), cache reuse via `WealthMarketUniverseStore.prepareCachedSnapshotForStartup()`, and a three-phase background sequence (universe reload → AI scan → market warmup).

2. **`WealthEngineStartupController` → `beginStartupSequence()`**  
   An independent singleton managing its own `startupTask`, `isStartupComplete` flag, a four-phase staggered sequence (universe → AI → market ranking → research feeds) with inter-phase delays, and a call to `rescheduleTimers()` on completion.

`WealthEngineStore.bootstrap()` calls `WealthAppSessionController.prepareLaunch()` which calls `WealthEngineStartupController.beginStartupSequence()`. Nowhere does `bootstrap()` call `runActivationSequence()`. The two paths have different phases, different timers, different state flags, and different completion actions.

**Technical Impact**  
- If `runActivationSequence()` is called from WealthCore.swift (not in git), it runs a startup sequence in parallel with or instead of `WealthEngineStartupController`'s sequence, creating duplicate scan phases, double timer scheduling, and conflicting state flags.  
- If `runActivationSequence()` is NOT called, its infrastructure (startup phase enum, `activationTask` field, `phoneStartupScanDelayNanoseconds`) is dead code that consumes memory.  
- The reference to four timers in `runActivationSequence()` that includes `softTimer`, `heavyTimer`, `preScanBurstTimer`, and `scheduledCheckpointTimer` conflicts with `WealthEngineStore+Timers.swift` which only manages `softTimer` and `heavyTimer` (plus `timerHolder.ibkrTimers` and `timerHolder.extraSoftTimers`). This means `runActivationSequence()` attempts to nil out timer references that were never set by the new timer architecture.

---

### B-2 · `WealthEngineStartupController.beginStartupSequence()` Guard Prevents Re-Entry After Recovery

| | |
|---|---|
| **File** | `Wealth Creation/WealthEngineStartupController.swift` |
| **Function** | `beginStartupSequence()` |
| **Approx. line** | ~55 |

**Problem**  
```swift
guard startupTask == nil, !isStartupComplete else { return }
```
After a successful startup, `isStartupComplete = true`. If `cancelStartupSequence()` is later called (e.g. during factory reset), `isStartupComplete` is reset to `false`. But if startup was interrupted mid-sequence and `cancelStartupSequence()` was NOT called (e.g. crash/OOM), `isStartupComplete` is an in-memory property that resets to `false` on next app launch. This is safe. However, the recovery path in `WealthEngineRuntimeRecovery.runStartupIntegrityCheck()` does not call `cancelStartupSequence()` — it only cancels rebuilds and resets the ready-state gate. If `beginStartupSequence()` is called before `isStartupComplete = false` is set (timing gap), the guard fires and startup silently skips.

**Technical Impact**  
A race between the integrity check and the startup controller can cause the startup sequence to be a permanent no-op, leaving the engine empty after a recovery cycle.

---

## Theme C — Threading / Concurrency Hazards {#theme-c}

---

### C-1 · `nonisolated(unsafe)` Timer Holder Creates Unguarded Data Races

| | |
|---|---|
| **File** | `Wealth Creation/WealthEngineStore+Timers.swift` |
| **Declaration** | `private nonisolated(unsafe) let timerHolder = WealthTimerHolder()` |
| **Approx. line** | ~31 |

**Problem**  
`timerHolder` is declared `nonisolated(unsafe)`, which opts out of Swift's actor-isolation concurrency checking. The accompanying comment claims access is always serialized because `WealthEngineStore` is a `@MainActor` singleton. However, the three timer callback closures each create a `Task.detached(priority: .userInitiated)`, which runs on arbitrary background threads. The detached tasks call `self?.refresh(mode:)`, which calls through to `performMarketRanking()` and other methods. If `rescheduleTimers()` is called on the main actor while a detached task is executing, `timerHolder.ibkrTimers.removeAll()` executes on the main actor while the background task may be indirectly holding a reference obtained from `timerHolder`. Swift's concurrency checker does not enforce this due to `nonisolated(unsafe)`.

**Technical Impact**  
Potential use-after-free or array mutation crash if `rescheduleTimers()` (which calls `invalidateTimers()` → `timerHolder.ibkrTimers.removeAll()`) is called while a timer-triggered detached task is in flight. The `nonisolated(unsafe)` annotation suppresses the compiler warning that would otherwise flag this.

---

### C-2 · Double `[weak self]` Capture Chain in Timer Callbacks Can Silently Drop Work

| | |
|---|---|
| **File** | `Wealth Creation/WealthEngineStore+Timers.swift` |
| **Functions** | `makeIBKRTimer(at:stage:)`, `makeSoftTimer(at:stage:)`, `makeDeepTimer(at:stage:)` |
| **Approx. lines** | ~90–130 |

**Problem**  
Each timer callback has this structure:
```swift
Timer.scheduledTimer(...) { [weak self] _ in
    guard let self else { return }          // outer guard
    Task { @MainActor [weak self] in        // second weak capture
        guard let self else { return }      // inner guard
        self.activationStage = stage
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.refresh(mode: ...)  // third weak capture — no guard
        }
    }
}
```
The outer closure captures `self` weakly and then re-captures it weakly in the `Task { @MainActor }` block. Between the two guard points, `self` could be deallocated (though unlikely for a `@MainActor` singleton). More critically, the innermost `Task.detached` uses `self?` without a `guard let self` — if `self` is nil, `refresh(mode:)` is silently not called. No error or log entry is produced.

**Technical Impact**  
Deallocation of the engine store (or any scenario where `self` becomes nil before the Task executes) will silently skip the refresh without any indication in logs. For a singleton this is unlikely, but the pattern is fragile and inconsistent with the three-level chain (outer checks, inner silent-nil).

---

### C-3 · `@MainActor` Scan Stubs Called via `Task.detached` — Actor Hop Serializes Background Work

| | |
|---|---|
| **File** | `Wealth Creation/WealthEngineStore+Refresh.swift` |
| **Functions** | `runUniverseScan()`, `runAIScan()`, `runMarketRanking()`, `runResearchFeeds()` |
| **Approx. lines** | ~40–60 |

**Problem**  
Each entry-point wraps the actual scan in a `Task.detached(priority: .userInitiated)` whose sole purpose is to call a `@MainActor`-isolated method:
```swift
func runAIScan() async {
    await Task.detached(priority: .userInitiated) { [weak self] in
        await self?.performAIScan()   // @MainActor → hops back to main thread
    }.value
}
```
Since `performAIScan()` is `@MainActor`, the detached task immediately hops back to the main actor. The detach adds overhead (new thread, context switch) with no actual concurrency benefit for the stub implementations.

**Technical Impact**  
When `performAIScan()` (currently the only non-empty scan stub) calls `WealthBrainStore.shared.ingest()` and `materializeMarketCandidates()`, this all runs on the main actor anyway. The `Task.detached` pattern was designed for future CPU-bound background work, but as currently implemented it creates unnecessary scheduling overhead. More importantly, it means the scan phases in the startup sequence run serially on the main actor despite appearing to be background work, which blocks UI during scan execution once real implementations are in place.

---

### C-4 · `WealthEngineStore+BackgroundCache.swift` — `save()` Called Synchronously on `applicationWillTerminate`

| | |
|---|---|
| **File** | `Wealth Creation/WealthAppSessionController.swift` |
| **Function** | `applicationWillTerminate()` |
| **Approx. line** | ~115 |

**Problem**  
`applicationWillTerminate()` calls `WealthEngineStore.shared.save()` (the synchronous variant from `WealthEngineStore+Cache.swift`). The synchronous `save()` calls `persistRankedAssetsToFile()`, `persistScannedSignalsToFile()`, and `persistHoldingsToFile()`, which call `try? JSONEncoder().encode(rankedAssets)`. On a dataset of 128k ranked assets, JSON encoding on the main thread can take several seconds. iOS gives apps approximately 5 seconds on `applicationWillTerminate` before force-killing the process.

**Technical Impact**  
On termination with a large `rankedAssets` array, the synchronous JSON encode will exceed the 5-second window. The file writes will be incomplete or not executed at all, silently losing the engine's current state. This contradicts the comment "Persists the current engine snapshot synchronously so data is not lost on a clean termination."

---

## Theme D — Placeholder Risk Metrics in the Safeguard Gate {#theme-d}

---

### D-1 · `earningsRisk` Is a Generic Risk Proxy, Not Earnings Risk

| | |
|---|---|
| **File** | `Wealth Creation/Opportunity+CardStateMachine.swift` |
| **Property** | `earningsRisk` |
| **Approx. line** | ~55–62 |

**Problem**  
```swift
var earningsRisk: Int {
    Int((risk * 100).rounded())
}
```
The property maps the existing generic `risk` float (0–1 range) to 0–100. The source comment explicitly states:  
> "⚠️ PLACEHOLDER — Replace this computed property with the dedicated earnings-risk field... The current derivation from the generic `risk` float is NOT semantically equivalent to earnings-specific risk and WILL produce incorrect safeguard decisions in production until replaced."

**Used in**  
- `WealthEngineStore+Materialization.swift` → `evaluateSafeguards()` → earningsRisk ≥ 70 triggers rejection  
- `WealthAILiveCoordinator+Evaluation.swift` → earningsRisk < 70 required for AI Live promotion  
- `WealthAILiveRejectionAudit.swift` → counts cards with earningsRisk ≥ 70  

**Technical Impact**  
Any opportunity with a generic `risk` score ≥ 0.70 is blocked from Market ranking AND from AI Live promotion, regardless of whether it has any actual earnings event risk. Conversely, a genuinely high-risk earnings-event card with a low generic `risk` value passes the gate. The safeguard gate — the primary quality filter before live trading — is applying the wrong threshold to the wrong metric. This is acknowledged in code but represents a live data correctness defect.

---

### D-2 · `macroRisk` Is an Inverted Probability, Not Macro Risk

| | |
|---|---|
| **File** | `Wealth Creation/Opportunity+CardStateMachine.swift` |
| **Property** | `macroRisk` |
| **Approx. line** | ~65–72 |

**Problem**  
```swift
var macroRisk: Int {
    Int(((1.0 - probability) * 100).rounded())
}
```
`macroRisk` is derived by inverting the `probability` field: high probability → low macro risk, low probability → high macro risk. The source comment states:  
> "⚠️ PLACEHOLDER — Replace this computed property with a dedicated macro/geopolitical risk field... WILL produce incorrect safeguard decisions in production until replaced."

**Used in**  
Same gates as `earningsRisk` above, with a threshold of ≥ 75.

**Technical Impact**  
Any opportunity with a trade probability below 0.25 (low-confidence) automatically exceeds the macroRisk threshold (> 75) and is blocked from Market ranking and AI Live regardless of actual geopolitical/macro context. High-probability cards are always considered macro-safe, conflating trade confidence with macro stability. This inverted heuristic can distort the entire ranked universe, silently blocking or allowing cards based on wrong criteria.

---

## Theme E — Circular Rebuild Cascade Risk {#theme-e}

---

### E-1 · `wealthEngineDidBecomeReady` Notification Can Trigger a Rebuild Loop

| | |
|---|---|
| **Files** | `WealthDownstreamCacheSanity.swift`, `WealthReadyStateGate.swift`, `WealthNewComponentsBootstrap.swift` |
| **Functions** | `validatePersistedDownstreamState()`, `markDownstreamRebuildComplete()`, `runPostReadyPipeline()` |

**Problem**  
The notification chain is:
1. `WealthReadyStateGate.markDownstreamRebuildComplete()` → posts `wealthEngineDidBecomeReady`  
2. **Observer 1** (`WealthDownstreamCacheSanity.init()` observer): calls `validatePersistedDownstreamState()`  
3. `validatePersistedDownstreamState()` checks file freshness. If any downstream cache file is stale or missing, it calls `WealthStaleCacheDetector.checkAndRebuildIfNeeded()`  
4. `checkAndRebuildIfNeeded()` calls `WealthDownstreamRebuildOrchestrator.triggerRebuild(reason:)`  
5. The rebuild runs AI scan + market ranking, then calls `WealthReadyStateGate.markDownstreamRebuildComplete()`  
6. `markDownstreamRebuildComplete()` checks: `!wasReady && isFullyReady`. After the first rebuild, `wasReady = true`, so it doesn't re-post. The loop stops.

**BUT** — **Observer 2** (`WealthNewComponentsBootstrap.activate()` observer): calls `runPostReadyPipeline()`, which calls `WealthDownstreamCacheSanity.shared.saveMarketSnapshot()`, `saveAILiveResults()`, and `saveActivityState()`. These file writes happen asynchronously. If `validatePersistedDownstreamState()` (Observer 1) runs its freshness check (`isFileFresh(at:)`) before Observer 2 completes the file writes, the files appear absent/stale, triggering another rebuild. The rebuild completes, posts `wealthEngineDidBecomeReady` again — but `wasReady = true` at this point, so `markDownstreamRebuildComplete()` does NOT post the notification again. The second rebuild is technically prevented from re-triggering, but it still executes unnecessarily.

**Technical Impact**  
On app startup, a second (spurious) downstream rebuild can execute immediately after the first, doubling the AI scan + market ranking workload for no benefit. The freshness check races with the file writes from `runPostReadyPipeline()`. Under memory pressure or on slow storage, this race is more likely to trigger. The resulting second rebuild consumes CPU, delays timer scheduling, and may cause UI thrash from two rapid `objectWillChange.send()` calls.

---

### E-2 · `WealthPortfolioLifecycleHelper` Retry Loop Has No Backoff

| | |
|---|---|
| **File** | `Wealth Creation/WealthPortfolioStore+LifecycleHelpers.swift` |
| **Function** | `scheduleArmedRetry(attemptsRemaining:)` |
| **Approx. line** | ~72 |

**Problem**  
```swift
private func scheduleArmedRetry(attemptsRemaining: Int) {
    ...
    retryTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        guard !Task.isCancelled, let self else { return }
        if WealthPortfolioStore.shared.tradingLifecycleArmed {
            self.triggerAdmissionRerun()
        } else {
            self.scheduleArmedRetry(attemptsRemaining: attemptsRemaining - 1)
        }
    }
}
```
Each retry creates a new `Task` and assigns it to `retryTask`. The previous task reference is overwritten without being cancelled. Up to `maxRetryAttempts` (30) tasks are created, each sleeping 1 second. While older tasks will eventually complete by checking `tradingLifecycleArmed`, there is no cancellation of the previous retry `Task` before overwriting `retryTask`. Only the most recent retry task is cancellable via `retryTask?.cancel()`.

**Technical Impact**  
If `triggerAdmissionRerun()` cancels `retryTask`, it only cancels the most recent retry. Older retry tasks continue sleeping and will eventually call either `triggerAdmissionRerun()` or `scheduleArmedRetry()` again when they wake. This can cause `rerunActivityAdmissionAfterStartup()` to be called multiple times. On slow startup (where `tradingLifecycleArmed` takes many seconds to become true), up to 30 orphaned Tasks are live simultaneously.

---

## Theme F — Scan-Progress Notifications Dead After Startup {#theme-f}

---

### F-1 · `WealthEngineScanScheduler` Phases Are Never Reset Between Cycles

| | |
|---|---|
| **File** | `Wealth Creation/WealthEngineScanScheduler.swift` |
| **Function** | `markPhaseComplete(_:)` |
| **Approx. line** | ~67 |

**Problem**  
```swift
func markPhaseComplete(_ phase: ScanPhase) {
    guard !completedPhases.contains(phase) else { return }  // No-op if already done
    completedPhases.insert(phase)
    ...
    NotificationCenter.default.post(name: .wealthScanProgressDidUpdate, ...)
}
```
During startup, `runUniverseScanWithProgress()`, `runAIScanWithProgress()`, etc. call `markPhaseComplete()`. After startup, recurring timer refreshes call the non-progress variants (`runUniverseScan()`, `runAIScan()`), which do NOT call `markPhaseComplete()`. `WealthEngineScanScheduler.reset()` is never called after startup.

**Technical Impact**  
`currentProgress` is stuck at 1.0 after startup and `completedPhases` is never cleared. Any consumer subscribing to `wealthScanProgressDidUpdate` notifications receives no updates during the 10-, 20-, or 30-minute timer refresh cycles — only during the one-time startup. `WealthAILiveCoordinator.evaluateCandidates()` relies on `hasReachedAILiveGate` (which is `currentProgress >= 0.5`). Since progress stays at 1.0 after startup, this gate always passes on timer refreshes — which is correct behavior, but only by accident. If `reset()` were ever called mid-cycle (e.g. as part of a future recovery path), progress would drop to 0.0 and block all AI Live evaluation until progress wrappers were called again during the subsequent startup cycle.

---

### F-2 · Timer Refreshes Never Update `WealthEngineScanScheduler`

| | |
|---|---|
| **File** | `Wealth Creation/WealthEngineStore+Timers.swift` |
| **Functions** | `makeSoftTimer(at:stage:)`, `makeDeepTimer(at:stage:)` |
| **Approx. lines** | ~107–130 |

**Problem**  
Timers call `refresh(mode: .soft)` and `refresh(mode: .deep)`, which call `runSoftRefresh()` / `runDeepRefresh()`, which call `runUniverseScan()`, `runAIScan()`, etc. — the non-`WithProgress` variants. Only `runUniverseScanWithProgress()` and friends (called exclusively from `WealthEngineStartupController.runStartupSequence()`) report to `WealthEngineScanScheduler`.

**Technical Impact**  
The scan scheduler never sees timer-driven refresh phases. Its `currentProgress` permanently reflects only the startup run. Any future observer relying on `wealthScanProgressDidUpdate` or `wealthRefreshPhaseWillBegin`/`wealthRefreshPhaseDidComplete` for timer refreshes will receive no notifications. The lifecycle-publishing infrastructure (`WealthEngineRefresh+LifecyclePublishing.swift`) is effectively a startup-only feature despite being designed for recurring use.

---

## Theme G — Properties Referenced But Not in Git {#theme-g}

---

### G-1 · `WealthEngineStore+Activation.swift` References Six Uncommitted Properties

| | |
|---|---|
| **File** | `Wealth Creation/WealthEngineStore+Activation.swift` |
| **Function** | `runActivationSequence()` |

**Problem**  
The following properties are referenced in `runActivationSequence()` but their declarations exist only in `WealthCore.swift`, which is **not committed to git**:

| Property | Usage |
|---|---|
| `scheduledCheckpointTimer` | Invalidated at startup |
| `preScanBurstTimer` | Invalidated at startup |
| `downstreamRecoveryPending` | Set to `true` at startup start |
| `startupSequencePhase` | Set to `.waitingToScan`, then `.idle` |
| `phoneStartupScanDelayNanoseconds` | Used for `Task.sleep` duration |
| `lockedCheckpointProgress` | Set to `Self.lockedCheckpointCount` on completion |
| `Self.lockedCheckpointCount` | Static constant used for progress |
| `tradingLifecycleArmed` | Set to `true` on completion |

**Technical Impact**  
The entire `WealthEngineStore+Activation.swift` file compiles only if WealthCore.swift provides all these declarations with the correct types. Since WealthCore.swift is absent from git, there is no way to verify correctness. Any type mismatch, missing property, or renamed field causes a compile error that silently prevents the app from building. This is the most likely root cause of any CI/build failures reported for this repository.

---

### G-2 · Multiple Extensions Reference `WealthPortfolioStore` Properties Not in Git

| | |
|---|---|
| **Files** | `WealthPortfolioStore+Lifecycle.swift`, `WealthPortfolioStore+LifecycleHelpers.swift` |
| **Functions** | `rerunActivityAdmissionAfterStartup()`, `handleEngineReady()` |

**Problem**  
Both files reference `WealthPortfolioStore.shared.tradingLifecycleArmed` and `WealthPortfolioStore.shared.reconcileActivityAdmissions()`. `WealthPortfolioStore` is not defined in any committed Swift file.

**Technical Impact**  
Same compile-time risk as G-1. Additionally, `reconcileActivityAdmissions()` is the final step of the Activity admission pipeline — the function that actually populates the Activity queue. Its implementation, signature, and threading model are entirely unknown from the committed code. The wrapper `rerunActivityAdmissionAfterStartup()` in the committed code calls this unknown function after a 30-retry polling loop.

---

### G-3 · `WealthAllCardsStore.sync(...)` and `marketCardLimit` Not Defined in Git

| | |
|---|---|
| **File** | `Wealth Creation/WealthEngineStore+Materialization.swift` |
| **Functions** | `materializeMarketCandidates()`, `selectExecutableCandidates(from:)` |
| **Approx. lines** | ~75, ~105 |

**Problem**  
`WealthAllCardsStore.shared.sync(opportunities:activityKeys:holdingKeys:livePickKeys:refreshTime:)` and the constant `WealthAllCardsStore.marketCardLimit` are called inside `materializeMarketCandidates()`. `WealthAllCardsStore` is not defined in any committed Swift file.

**Technical Impact**  
The market ranking pipeline's final step — syncing ranked cards to the card store for UI presentation — depends entirely on an uncommitted type. `marketCardLimit` (used as a `prefix()` cap to limit Market candidates to 100) is an unnamed constant. If this type is missing or its static property has a different name, materialization fails silently (or crashes).

---

## Theme H — IBKR Market Data Never Delivered {#theme-h}

---

### H-1 · `subscribeMarketData()` Requests Are Made But Responses Are Discarded

| | |
|---|---|
| **File** | `Wealth Creation/WealthIBKRBridge+Send.swift` |
| **Function** | `subscribeMarketData(contract:)` |

**Problem**  
`subscribeMarketData()` sends a `REQ_MKT_DATA` (message ID 1) frame to TWS and returns a `reqID`. TWS will respond with a stream of `TICK_PRICE`, `TICK_SIZE`, and `TICK_STRING` messages (API message IDs 1, 2, 45 respectively). These responses arrive in `handleApiMessage(data:)` (see A-5 above), which is empty.

Additionally, the `subscriptions` dictionary in `WealthIBKRBridge` stores `[reqID: Subscription]` entries, but no code ever reads this dictionary to correlate incoming ticks with subscribed contracts.

**Technical Impact**  
Even if `performIBKRSync()` were implemented (it is not — see A-2), it would need to: (1) call `subscribeMarketData()`, (2) parse `handleApiMessage` responses to extract `WealthBrokerQuote`, (3) emit `.quote(WealthBrokerQuote)` events, and (4) apply quote prices to `rankedAssets`. None of these steps exist in committed code. The IBKR price-sync path is broken at three independent layers: the engine stub (A-2), the message parser (A-5), and the quote application logic (missing entirely).

---

## Summary Matrix {#summary-matrix}

| ID | File | Function / Location | Category | Severity | Impact |
|---|---|---|---|---|---|
| A-1 | `WealthEngineStore+Refresh.swift` | `performUniverseScan()` ~L85 | Empty stub | **Critical** | All scans produce no data |
| A-2 | `WealthEngineStore+Refresh.swift` | `performIBKRSync()` ~L100 | Empty stub | **Critical** | IBKR prices never update |
| A-3 | `WealthEngineStore+Refresh.swift` | `performResearchFeeds()` ~L92 | Empty stub | **High** | Research intel never appended |
| A-4 | `WealthBrainStore.swift` | `learn()`, `bias()` ~L65–73 | Empty stubs | **Critical** | Brain never adapts; scores never biased |
| A-5 | `WealthIBKRBridge.swift` | `handleApiMessage(data:)` ~L157 | Empty stub | **Critical** | All IBKR server messages discarded |
| B-1 | `WealthEngineStore+Activation.swift` + `WealthEngineStartupController.swift` | `runActivationSequence()` vs `beginStartupSequence()` | Duplicate startup | **Critical** | Two conflicting startup paths; timer double-fire risk |
| B-2 | `WealthEngineStartupController.swift` | `beginStartupSequence()` ~L55 | Guard race | **High** | Recovery cycle can silently skip startup |
| C-1 | `WealthEngineStore+Timers.swift` | `timerHolder` declaration ~L31 | `nonisolated(unsafe)` data race | **High** | Undetected timer array mutation crash |
| C-2 | `WealthEngineStore+Timers.swift` | `makeIBKRTimer/SoftTimer/DeepTimer` ~L90–130 | Weak-capture chain | **Medium** | Refresh silently skipped if self nil |
| C-3 | `WealthEngineStore+Refresh.swift` | `runAIScan()`, etc. ~L40–60 | Actor-hop overhead | **Medium** | Background dispatch does not provide real concurrency |
| C-4 | `WealthAppSessionController.swift` | `applicationWillTerminate()` ~L115 | Blocking main thread | **High** | Synchronous JSON encode exceeds 5s termination window |
| D-1 | `Opportunity+CardStateMachine.swift` | `earningsRisk` ~L55–62 | Wrong metric | **Critical** | Safeguard gate blocks/passes wrong cards |
| D-2 | `Opportunity+CardStateMachine.swift` | `macroRisk` ~L65–72 | Wrong metric | **Critical** | Safeguard gate conflates probability with macro risk |
| E-1 | `WealthDownstreamCacheSanity.swift` + `WealthReadyStateGate.swift` | `validatePersistedDownstreamState()` + `markDownstreamRebuildComplete()` | Circular cascade | **Medium** | Spurious second rebuild on every startup |
| E-2 | `WealthPortfolioStore+LifecycleHelpers.swift` | `scheduleArmedRetry(attemptsRemaining:)` ~L72 | Orphaned Tasks | **Medium** | Up to 30 concurrent Task leaks; multiple admission reruns |
| F-1 | `WealthEngineScanScheduler.swift` | `markPhaseComplete(_:)` ~L67 | No-op after startup | **Low** | Phase notifications dead during timer refreshes |
| F-2 | `WealthEngineStore+Timers.swift` | `makeSoftTimer`, `makeDeepTimer` ~L107–130 | Missing progress wiring | **Low** | Scan lifecycle events not published for recurring refreshes |
| G-1 | `WealthEngineStore+Activation.swift` | `runActivationSequence()` (multiple lines) | Missing declarations | **Critical** | Compile error if WealthCore.swift properties mismatch |
| G-2 | `WealthPortfolioStore+Lifecycle.swift` + Helpers | `rerunActivityAdmissionAfterStartup()` | Missing type | **Critical** | Activity admission pipeline depends on uncommitted type |
| G-3 | `WealthEngineStore+Materialization.swift` | `materializeMarketCandidates()` ~L75, L105 | Missing type | **Critical** | Card sync and market cap depend on uncommitted type |
| H-1 | `WealthIBKRBridge+Send.swift` | `subscribeMarketData()` | Broken pipeline | **Critical** | Market data subscriptions produce no quotes |

---

## Narrative Summary

The AWC Swift codebase has a layered architecture of new pipeline components (session controller, scan scheduler, rebuild orchestrator, audit runners, cache sanity checker) all wired together correctly at the integration layer. The notification flow, actor isolation, and guard patterns are generally sound in design. However, the entire pipeline sits on top of a foundation that is not in git (`WealthCore.swift`), and several of its most critical building blocks are explicitly empty stubs that acknowledge their own incompleteness in code comments.

The highest-severity issues cluster into three root causes:

1. **The core is missing.** `performUniverseScan()`, `performIBKRSync()`, `performResearchFeeds()`, `learn()`, `bias()`, and `handleApiMessage()` are all empty. No real data flows through the engine at runtime. Log entries, notifications, and audit reports all fire as if work was done, but every data array (`rankedAssets`, quotes, research intel) remains at its initial/cached state permanently.

2. **The risk metrics are wrong.** The safeguard gate — the primary quality filter before live trading decisions — runs on `earningsRisk` and `macroRisk` values that are explicitly documented as incorrect proxies for the intended metrics. Cards are filtered in or out of the live trading pipeline based on wrong criteria.

3. **The compiled surface area is larger than the committed source.** Critical extensions compile only if WealthCore.swift declares the exact properties they reference. With WealthCore.swift outside of git, every code review and CI run is incomplete, and any renaming or refactoring in WealthCore.swift silently breaks the committed extensions.

The new components (audit runners, cache sanity, lifecycle coordinator) provide excellent observability and recovery infrastructure. But they are ready-state gates and rebuild triggers waiting for real scan data that never arrives.
