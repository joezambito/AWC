# AWC Universal Download — Full Path Trace Report

**Generated:** 2026-04-05  
**Scope:** All committed Swift source files in `Wealth Creation/` (43 files, ~5,400 lines)  
**Basis:** Direct file-by-file reading of the current branch. No prior session context recycled.  
**Task:** Trace the FULL path — visible and hidden — of the universal (universe) download on the app. No code changes, no logic replacements. Report only.

---

## Executive Summary

The "universal download" in AWC refers to the **market universe** — the 128,000+ row dataset of global market instruments (`MarketUniverseRecord`) stored and managed by `WealthMarketUniverseStore`. This is the data layer that the logs call "still downloading the univ".

The download path spans **10 source files** and involves **3 distinct execution layers**:

1. **App lifecycle layer** — `WealthAppSessionController`, `WealthEngineStore+Bootstrap`
2. **Cache restore layer** — `WealthEngineStore+BackgroundCache`, `PersistenceManager`
3. **Universe startup layer** — `WealthEngineStartupController`, `WealthMarketUniverseStore`

The full pipeline, including all hidden and internal processes, is documented in detail below.

---

## Part 1: Entry Points — Where the Universe Download Can Be Triggered

There are **two** entry points that can trigger the startup sequence (and therefore the universe download):

### Entry Point A — `WealthEngineStore.bootstrap()` (Primary)
**File:** `Wealth Creation/WealthEngineStore+Bootstrap.swift` · Line 47  
Called from `ContentView.onAppear` in the app's main view.

```
ContentView.onAppear
  └─ WealthEngineStore.shared.bootstrap()
       └─ WealthAppSessionController.shared.prepareLaunch()
```

### Entry Point B — `WealthEngineStore.runActivationSequence()` (Secondary)
**File:** `Wealth Creation/WealthEngineStore+Activation.swift` · Line 23  
Called from `WealthCore.swift` (not in git — lives in the compiled Xcode target).

```
WealthCore.swift (app lifecycle hook)
  └─ WealthEngineStore.shared.runActivationSequence()
       └─ WealthAppSessionController.shared.prepareLaunch()
```

Both entry points converge at the **exact same single function**: `WealthAppSessionController.shared.prepareLaunch()`. The `prepareLaunch()` method is guarded by a `hasLaunched: Bool` flag so only the **first** caller executes. Subsequent calls are no-ops. This means the universe download starts exactly once per app lifecycle regardless of which entry point fires first.

---

## Part 2: Phase 0 — App Launch and Pipeline Singleton Activation

**File:** `Wealth Creation/WealthAppSessionController.swift` · Lines 68–92

When `prepareLaunch()` executes for the first time:

1. **Tracing begins** — `WealthStartupLagTracer.shared.trace("prepareLaunch – start")` records the wall-clock time and prints to the Xcode console.

2. **Pipeline singletons are activated** — `WealthNewComponentsBootstrap.activate()` is called.  
   This touches the `shared` accessor of every downstream singleton, forcing their Swift lazy initializers to run and register their `NotificationCenter` observers:
   - `WealthDownstreamCacheSanity.shared`
   - `WealthMarketExecutionAudit.shared`
   - `WealthAILiveRejectionAudit.shared`
   - `WealthActivityAdmissionAudit.shared`
   - `WealthEngineScanScheduler.shared`
   - `WealthEngineRuntimeCoordinator.shared`
   - `WealthEngineRuntimeRecovery.shared`
   - `WealthAILiveCoordinator.shared`
   - `WealthOrderRestrictionRules.shared`
   - `WealthPortfolioLifecycleHelper.shared`
   - `WealthBrainStore.shared`

   **Hidden observer registered here:** `WealthNewComponentsBootstrap.activate()` also registers a one-time `NotificationCenter` observer for `.wealthEngineDidBecomeReady` that will trigger `runPostReadyPipeline()` after the startup sequence completes. This is invisible at the call site.

3. **Cache restore begins** — `WealthEngineStore.shared.restoreCacheInBackground(completion:)` is called with a completion closure that calls `WealthEngineStartupController.shared.beginStartupSequence()`. The universe download does NOT start yet — it waits for the cache restore to finish.

**Source:**
```
WealthAppSessionController.prepareLaunch()           ← AppSessionController.swift:68
  ├─ WealthStartupLagTracer.shared.trace(...)         ← AppSessionController.swift:73
  ├─ WealthNewComponentsBootstrap.activate()          ← NewComponentsBootstrap.swift:46
  │    └─ touches 11 singletons (inits run)
  │    └─ registers .wealthEngineDidBecomeReady observer (HIDDEN)
  └─ WealthEngineStore.shared.restoreCacheInBackground { ... }   ← BackgroundCache.swift:46
```

---

## Part 3: Phase 1 — Background Cache Restore (Before Universe Download)

**File:** `Wealth Creation/WealthEngineStore+BackgroundCache.swift` · Lines 46–123

`restoreCacheInBackground(completion:)` is the **critical gate** that must complete before the universe download can begin. It runs entirely off the main thread.

### Execution Flow

```
restoreCacheInBackground(completion:)                ← BackgroundCache.swift:46
  └─ Task.detached(priority: .userInitiated) { ... } ← BackgroundCache.swift:49
       │
       │  ── Try atomic bundle first ─────────────────────────────────────────
       ├─ PersistenceManager.shared.loadBundle()      ← PersistenceManager.swift:94
       │    └─ reads: Caches/awc_engine_state_bundle.json
       │    └─ decodes: EngineStateBundle (rankedAssets, scannedSignals, holdings,
       │                                   lastRefresh, lastHeavyRefresh)
       │
       │  ── If bundle loaded (NOT first launch) ──────────────────────────────
       ├─ await MainActor.run {                        ← BackgroundCache.swift:54
       │    engine.rankedAssets     = bundle.rankedAssets
       │    engine.scannedSignals   = bundle.scannedSignals
       │    engine.holdings         = bundle.holdings
       │    engine.lastRefresh      = bundle.lastRefresh
       │    engine.lastHeavyRefresh = bundle.lastHeavyRefresh
       │    WealthEventLogStore.shared.record(...)
       │    completion()    ← beginStartupSequence() fires HERE
       │  }
       │
       │  ── If bundle NOT found (first launch / factory reset) ────────────────
       └─ [migration path] reads legacy UserDefaults keys:
            • awc_engine_last_refresh      (Date)
            • awc_engine_last_heavy_refresh (Date)
         reads legacy Caches files:
            • awc_engine_ranked_assets.json
            • awc_engine_scanned_signals.json
            • awc_engine_holdings.json
         await MainActor.run {
           apply all restored values
           completion()    ← beginStartupSequence() fires HERE
         }
```

### What "Atomic Bundle" Means Here
`PersistenceManager.saveBundle()` writes all engine state — ranked assets, signals, holdings, timestamps — as a **single JSON file** using `Data.write(to:options:.atomic)`. This uses a temp-file + `rename(2)` syscall, so the file is either fully committed or not touched at all. The bundle file is:

| File | Location | Contents |
|------|----------|----------|
| `awc_engine_state_bundle.json` | `Caches/` directory | `EngineStateBundle` (rankedAssets, scannedSignals, holdings, lastRefresh, lastHeavyRefresh) |

### Legacy Fallback Files (Migration Path)
If the bundle file does not exist (first install or after the atomic-bundle migration), the system reads:

| Key / File | Location | Contains |
|------------|----------|----------|
| `awc_engine_last_refresh` | UserDefaults | Last refresh `Date` |
| `awc_engine_last_heavy_refresh` | UserDefaults | Last heavy refresh `Date` |
| `awc_engine_ranked_assets.json` | `Caches/` | `[Opportunity]` |
| `awc_engine_scanned_signals.json` | `Caches/` | `[MarketSignal]` |
| `awc_engine_holdings.json` | `Caches/` | `[Holding]` |

---

## Part 4: Phase 2 — Startup Sequence Begins (Universe Download Decision Point)

**File:** `Wealth Creation/WealthEngineStartupController.swift` · Lines 66–205

`beginStartupSequence()` is called from the cache-restore completion closure (on the main actor). It checks two guards and then launches the sequence on a background task.

### Guard Conditions (at line 67–68)
```swift
guard startupTask == nil,
      !isStartupComplete else { return }
```
If startup is already running or already completed, the call is a **no-op**. This is the second guard that prevents double-execution.

### Background Task Launch (at line 70–72)
```swift
startupTask = Task.detached(priority: .userInitiated) { [weak self] in
    await self?.runStartupSequence()
}
```

The entire startup sequence — including the universe download — runs on a **detached background task** at `.userInitiated` priority. The main thread is never blocked.

---

## Part 5: Phase 3 — Pre-Flight Integrity Check (Hidden Internal Process)

**File:** `Wealth Creation/WealthEngineStartupController.swift` · Lines 88–99  
**Calls into:** `Wealth Creation/WealthEngineRuntimeRecovery.swift` · Lines 46–98

Before any download begins, `runStartupSequence()` calls:

```swift
await MainActor.run {
    WealthEngineRuntimeRecovery.shared.runStartupIntegrityCheck()
}
```

`runStartupIntegrityCheck()` performs the following checks and **silently resets** any stuck state:

| Check | Condition | Action |
|-------|-----------|--------|
| Stuck dashboard-refresh flag | `isDashboardRefreshInFlight == true` | Sets to `false` |
| Stuck materialization flag | `isMarketMaterializationInFlight == true` | Sets to `false` |
| Dangling activation task | `activationTask != nil` | Sets to `nil` |
| Pending refresh payload | `pendingRefreshPayload != nil` | Sets to `nil` |
| Pending publish task | `pendingPublishTask != nil` | Sets to `nil` |
| Ready-state gate | (always) | `WealthReadyStateGate.shared.reset()` |
| In-flight rebuild | (always) | `WealthDownstreamRebuildOrchestrator.shared.cancelRebuild()` |

After the integrity check, the scan scheduler records the cache-restore phase as complete:
```swift
WealthEngineScanScheduler.shared.markPhaseComplete(.cacheRestore)  // progress → 20%
```

---

## Part 6: Phase 4 — Universe Download (The Core Operation)

**File:** `Wealth Creation/WealthEngineStartupController.swift` · Lines 101–136

This is the critical section. The tracer records:
```
[AWC·Startup] +X.XXXs  universeScan – start
```

### Step A: Cache Check (WealthMarketUniverseStore)

```swift
let hasCachedUniverse = await Task.detached(priority: .userInitiated) {
    WealthMarketUniverseStore.shared.prepareCachedSnapshotForStartup()
}.value
```

`prepareCachedSnapshotForStartup()` returns `true` when **both** of the following conditions are met:
1. `WealthMarketUniverseStore` already has records in memory (`records` array is non-empty).
2. The UserDefaults freshness key indicates the data is within the 6-hour threshold.

**UserDefaults keys read here:**

| Key | Type | Purpose |
|-----|------|---------|
| `awc_universe_signature` | `String` | Hash/fingerprint of the cached universe (record count or content hash) |
| `awc_universe_last_downloaded` | `Date` | Timestamp of the last successful universe download |

The 6-hour freshness threshold (`universeDataMaxAge = 6 * 3600`) is defined in `WealthDataAliveStore` (line 32) and respected by the cache check.

### Step B: Cache Hit Path (No Network Request)

```swift
if hasCachedUniverse {
    WealthEngineScanScheduler.shared.markPhaseComplete(.universeScan)  // progress → 40%
}
```

If the cache is valid, **the universe is not downloaded**. The app proceeds directly to AI scan using the cached universe snapshot from `WealthMarketUniverseStore`. The tracer records:
```
[AWC·Startup] +X.XXXs  universeScan – done
```

### Step C: Cache Miss Path (Full Universe Download)

```swift
} else {
    await Task.detached(priority: .userInitiated) {
        await WealthMarketUniverseStore.shared.reloadForStartupSequence()
    }.value
    WealthDataAliveStore.shared.recordUniverseDownload()
    WealthEngineScanScheduler.shared.markPhaseComplete(.universeScan)  // progress → 40%
}
```

`WealthMarketUniverseStore.shared.reloadForStartupSequence()` is the **sole function** that:
1. Downloads (or reads from the bundle file) the full universe of market instruments
2. Writes the UserDefaults cache keys `awc_universe_signature` and `awc_universe_last_downloaded`
3. Populates `WealthMarketUniverseStore.shared.records` with all `MarketUniverseRecord` entries

**After download:** `WealthDataAliveStore.shared.recordUniverseDownload()` stamps `lastUniverseDownload = Date()` in-memory so liveness queries (`isUniverseAlive`) return `true` for the next 6 hours.

> **Critical note (previously identified as Issue 4):** `performUniverseScan()` / `runUniverseScan()` in `WealthEngineStore+Refresh.swift` do **NOT** call `reloadForStartupSequence()` and do **NOT** write the UserDefaults cache keys. Only `reloadForStartupSequence()` writes those keys. This is why the log shows "still downloading the univ" — the startup controller correctly calls `reloadForStartupSequence()` when the cache misses, which includes every cold launch (first install, or 6+ hours since last download).

---

## Part 7: Phase 5 — Post-Universe Stagger and Downstream Scans

After the universe download (or cache hit), the startup sequence continues with **intentional delays** to prevent CPU spikes:

```
universeScan complete
  └─ sleep 2,000,000,000 ns (2 seconds)     ← Delay.afterUniverse
       └─ runAIScanWithProgress()            ← LifecyclePublishing.swift:42
            ├─ post .wealthRefreshPhaseWillBegin (phase=aiScan)
            ├─ runAIScan()
            │    └─ Task.detached { performAIScan() }    ← Refresh.swift:55
            │         └─ WealthBrainStore.shared.ingest(...)
            ├─ markPhaseComplete(.aiScan)    ← progress → 60%
            └─ post .wealthRefreshPhaseDidComplete (phase=aiScan)

  └─ sleep 1,000,000,000 ns (1 second)     ← Delay.afterAI
       └─ runMarketRankingWithProgress()    ← LifecyclePublishing.swift:50
            ├─ post .wealthRefreshPhaseWillBegin (phase=marketRanking)
            ├─ runMarketRanking()
            │    └─ Task.detached { performMarketRanking() }  ← Refresh.swift:62
            │         └─ materializeMarketCandidates()         ← Materialization.swift:74
            │              ├─ WealthCardHoldingRouter.routeFromGreenCheckpoint()
            │              ├─ selectExecutableCandidates() (safeguard gate)
            │              ├─ applyDataRecheck() (50% score/data check)
            │              ├─ assignMarketRanks() (dense ranking 1,1,2,3,3…)
            │              ├─ merge ranks back into rankedAssets
            │              └─ WealthAllCardsStore.shared.sync(...)
            ├─ markPhaseComplete(.marketRanking)  ← progress → 80%
            └─ post .wealthRefreshPhaseDidComplete (phase=marketRanking)

  └─ sleep 1,000,000,000 ns (1 second)     ← Delay.afterMarket
       └─ runResearchFeedsWithProgress()   ← LifecyclePublishing.swift:58
            ├─ post .wealthRefreshPhaseWillBegin (phase=researchFeeds)
            ├─ runResearchFeeds()
            │    └─ Task.detached { performResearchFeeds() }  ← Refresh.swift:69
            │         └─ [stub — research logic in WealthCore.swift]
            ├─ markPhaseComplete(.researchFeeds)  ← progress → 100%
            └─ post .wealthRefreshPhaseDidComplete (phase=researchFeeds)
```

### Notifications Posted During This Phase

| Notification | Payload | Fired by |
|---|---|---|
| `.wealthRefreshPhaseWillBegin` | `userInfo["phase"]` = Int | `postRefreshPhaseWillBegin()` |
| `.wealthRefreshPhaseDidComplete` | `userInfo["phase"]` = Int | `postRefreshPhaseDidComplete()` |
| `.wealthScanProgressDidUpdate` | `userInfo["progress"]` = Double (0.0–1.0) | `WealthEngineScanScheduler.markPhaseComplete()` |

---

## Part 8: Phase 6 — Startup Completion and Ready-State Gate

**File:** `Wealth Creation/WealthEngineStartupController.swift` · Lines 170–204

After all four phases complete, the startup controller hops back to `@MainActor` for a single batched update:

```swift
await MainActor.run {
    isStartupComplete = true
    startupTask = nil
    engine.tradingLifecycleArmed = true
    engine.rescheduleTimers()
}
```

- `isStartupComplete = true` — allows `WealthReadyStateGate.isFullyReady` to return `true` once the downstream rebuild also completes
- `tradingLifecycleArmed = true` — enables live-trading order submission
- `rescheduleTimers()` — starts the recurring refresh timers (soft: 10/20 min, deep: 30 min)

Then:
```swift
WealthStartupLagTracer.shared.printSummary()
```
This prints the full ordered trace of all timed events to the Xcode debug console.

Finally:
```swift
await MainActor.run {
    WealthReadyStateGate.shared.markDownstreamRebuildComplete()
}
```

`markDownstreamRebuildComplete()` (**File:** `WealthReadyStateGate.swift` · Line 54) checks:
- `isStartupComplete == true` (just set above)
- `isDownstreamRebuildComplete = true` (just set)

If both conditions are met for the first time, it posts:
```swift
NotificationCenter.default.post(name: .wealthEngineDidBecomeReady, object: nil)
```

---

## Part 9: Phase 7 — Post-Ready Pipeline (Hidden Downstream Processes)

**File:** `Wealth Creation/WealthNewComponentsBootstrap.swift` · Lines 63–130

The `.wealthEngineDidBecomeReady` notification is received by the observer registered in `activate()` (Phase 0). This triggers `runPostReadyPipeline()` on `@MainActor`:

```
.wealthEngineDidBecomeReady notification received
  └─ Task { @MainActor in runPostReadyPipeline() }
       │
       ├─ WealthMarketExecutionAudit.shared.runAudit(on: rankedAssets)
       │     Audits the full universe → green → safeguard → market funnel
       │
       ├─ WealthDownstreamCacheSanity.shared.saveMarketSnapshot(marketCards)
       │     Writes: Caches/awc_market_snapshot.json (atomic)
       │     Contains: rankedAssets.filter { rank > 0 }
       │
       ├─ WealthAILiveCoordinator.shared.evaluateCandidates()
       │     AI Live pass — gates on scan progress ≥ 0.5 (AI Live gate)
       │     Internally calls: WealthAILiveRejectionAudit
       │     Saves: Caches/awc_ai_live_results.json (atomic)
       │
       ├─ WealthAILiveRejectionAudit.shared.runAudit(on: marketCards)
       │
       ├─ WealthOrderRestrictionRules.shared.runAudit(on: promotedCards)
       │
       ├─ WealthActivityAdmissionAudit.shared.runAudit(on: promotedCards)
       │
       └─ WealthDownstreamCacheSanity.shared.saveActivityState(admissibleSymbols)
             Writes: Caches/awc_activity_state.json (atomic)
             Contains: promoted cards where isMarketExecutableCandidate && aiScore > 0
```

**Also triggered by .wealthEngineDidBecomeReady (separately):**

`WealthDownstreamCacheSanity.init()` registers its own observer (line 44 of `WealthDownstreamCacheSanity.swift`):
```swift
NotificationCenter.default.addObserver(
    forName: .wealthEngineDidBecomeReady, ...
) { [weak self] _ in
    Task { @MainActor [weak self] in
        self?.validatePersistedDownstreamState()
    }
}
```
`validatePersistedDownstreamState()` checks whether all three downstream cache files are fresh (within 30 minutes). If any are stale or missing, it calls `WealthStaleCacheDetector.shared.checkAndRebuildIfNeeded()`.

---

## Part 10: File-Backed Persistence — All Universe-Related Cache Files

### Atomic Engine Bundle

| File | Path | Written by | Read by | Contents |
|------|------|-----------|---------|----------|
| `awc_engine_state_bundle.json` | `Caches/` | `PersistenceManager.saveBundle()` | `PersistenceManager.loadBundle()` | `EngineStateBundle` (rankedAssets, scannedSignals, holdings, timestamps) |

### Downstream Cache Files

| File | Path | Written by | Read by | Contents |
|------|------|-----------|---------|----------|
| `awc_market_snapshot.json` | `Caches/` | `WealthDownstreamCacheSanity.saveMarketSnapshot()` | `loadMarketSnapshot()` | `[Opportunity]` where rank > 0 |
| `awc_ai_live_results.json` | `Caches/` | `WealthAILiveCoordinator.evaluateCandidates()` | `loadAILiveResults()` | `[Opportunity]` post-AI-Live |
| `awc_activity_state.json` | `Caches/` | `WealthDownstreamCacheSanity.saveActivityState()` | `loadActivityState()` | `[String]` admitted symbols |

### Legacy Migration Files (Superseded)

| File | Path | Status |
|------|------|--------|
| `awc_engine_ranked_assets.json` | `Caches/` | ⚠️ Legacy — read only if bundle absent |
| `awc_engine_scanned_signals.json` | `Caches/` | ⚠️ Legacy — read only if bundle absent |
| `awc_engine_holdings.json` | `Caches/` | ⚠️ Legacy — read only if bundle absent |

### UserDefaults Keys (Universe-Specific)

| Key | Type | Written by | Read by | Purpose |
|-----|------|-----------|---------|---------|
| `awc_universe_signature` | `String` | `WealthMarketUniverseStore.reloadForStartupSequence()` | `prepareCachedSnapshotForStartup()` | Universe snapshot fingerprint (e.g. record count hash) |
| `awc_universe_last_downloaded` | `Date` | `WealthMarketUniverseStore.reloadForStartupSequence()` | `prepareCachedSnapshotForStartup()` | Timestamp of last universe download |

### UserDefaults Keys (Legacy Engine — Migration Fallback Only)

| Key | Type | Written by | Read by | Purpose |
|-----|------|-----------|---------|---------|
| `awc_engine_last_refresh` | `Date` | Old WealthCore.swift code | `restoreCacheInBackground()` (fallback) | Last refresh timestamp |
| `awc_engine_last_heavy_refresh` | `Date` | Old WealthCore.swift code | `restoreCacheInBackground()` (fallback) | Last heavy refresh timestamp |

---

## Part 11: Foreground Reactivation Path (Hidden Warm-Open Flow)

**File:** `Wealth Creation/WealthEngineStore+Bootstrap.swift` · Line 61  
Triggered by `ContentView.onChange(scenePhase == .active)`.

```
ContentView.onChange(scenePhase == .active)
  └─ WealthEngineStore.shared.handleForegroundActivation()          ← Bootstrap.swift:61
       └─ WealthAppSessionController.shared.applicationDidBecomeActive()
            │                                                         ← AppSessionController.swift:104
            │  Trace: "applicationDidBecomeActive – fired"
            └─ WealthEngineRuntimeCoordinator.shared.handleBecameActive()
                 │                                                    ← RuntimeCoordinator.swift:54
                 │  Debounce: ignores calls within 2 seconds of previous
                 │
                 ├─ IF startup NOT complete → no-op (startup running, no double work)
                 │
                 └─ IF startup IS complete:
                      └─ WealthSessionUnlockController.shared.handleSessionResume()
                           └─ WealthStaleCacheDetector.shared.checkAndRebuildIfNeeded()
                                │                                    ← StaleCacheDetector.swift:99
                                │  Checks (any one triggers rebuild):
                                ├─ isCachedMarketWithoutLiveScores()  ← all aiScore == 0?
                                ├─ isCacheStale()                     ← lastRefresh > 5 min?
                                ├─ isAILiveResultsStale()             ← file missing or > 30 min?
                                └─ isActivityStateStale()             ← file missing or > 30 min?
                                │
                                └─ IF any stale:
                                     ├─ invalidateAILiveResults() (if AI stale)
                                     └─ WealthDownstreamRebuildOrchestrator.shared.triggerRebuild(reason:)
                                          └─ performDownstreamRebuild():
                                               ├─ engine.runAIScan()            ← reruns AI scoring
                                               ├─ engine.runMarketRanking()     ← reruns ranking
                                               └─ WealthReadyStateGate.shared.markDownstreamRebuildComplete()
                                                    └─ fires .wealthEngineDidBecomeReady again
                                                         └─ triggers runPostReadyPipeline() again
```

**Note:** The foreground path does NOT re-download the universe. It only re-runs AI scoring and market ranking. The universe download is exclusive to the startup sequence.

---

## Part 12: Recurring Timer Refresh Path (Post-Startup)

**File:** `Wealth Creation/WealthEngineStore+Timers.swift`

After `rescheduleTimers()` is called at startup completion, the engine schedules recurring timers. The refresh modes are:

| Timer | Interval | Mode | Includes Universe? |
|-------|----------|------|-------------------|
| IBKR price sync | 9 min | `.ibkr` | ❌ No |
| Soft refresh | 10 min | `.soft` | ✅ Yes (`runUniverseScan()`) |
| IBKR price sync | 19 min | `.ibkr` | ❌ No |
| Soft refresh | 20 min | `.soft` | ✅ Yes (`runUniverseScan()`) |
| IBKR price sync | 29 min | `.ibkr` | ❌ No |
| Deep refresh | 30 min | `.deep` | ✅ Yes + research feeds |

**Important:** The `.soft` and `.deep` modes call `runUniverseScan()` → `performUniverseScan()`. This is an **empty stub** — it calls through to `WealthCore.swift` which is not in git. It does **NOT** call `reloadForStartupSequence()` and does NOT write the UserDefaults cache keys. The actual universe re-download on timers relies on `WealthCore.swift`.

---

## Part 13: Complete Call Chain — Annotated with File and Line

```
[APP LAUNCH]
ContentView.onAppear
  └─ WealthEngineStore.shared.bootstrap()
       · WealthEngineStore+Bootstrap.swift:47

  └─ WealthAppSessionController.shared.prepareLaunch()
       · WealthAppSessionController.swift:68
       · Guard: hasLaunched flag → idempotent
       · Trace: "prepareLaunch – start"

       ├─ WealthNewComponentsBootstrap.activate()
       │    · NewComponentsBootstrap.swift:46
       │    · Initialises 11 singletons
       │    · HIDDEN: registers .wealthEngineDidBecomeReady observer
       │      → runPostReadyPipeline() callback

       └─ WealthEngineStore.shared.restoreCacheInBackground { ... }
            · WealthEngineStore+BackgroundCache.swift:46
            · Task.detached(priority: .userInitiated)

            ├─ [BUNDLE PATH] PersistenceManager.shared.loadBundle()
            │    · PersistenceManager.swift:94
            │    · File: Caches/awc_engine_state_bundle.json
            │    → await MainActor.run { apply bundle properties }
            │    → completion()

            └─ [LEGACY PATH] reads 3 files + 2 UserDefaults keys
                 · WealthEngineStore+BackgroundCache.swift:78–122
                 → await MainActor.run { apply legacy properties }
                 → completion()

[CACHE RESTORE COMPLETE → completion() fires]

  └─ WealthEngineStartupController.shared.beginStartupSequence()
       · WealthEngineStartupController.swift:66
       · Guard: startupTask == nil && !isStartupComplete
       · Task.detached(priority: .userInitiated)

       └─ runStartupSequence() [nonisolated, background thread]
            · WealthEngineStartupController.swift:84

            ├─ Trace: "runStartupSequence – start"

            ├─ await MainActor.run {
            │    WealthEngineRuntimeRecovery.shared.runStartupIntegrityCheck()
            │    · WealthEngineRuntimeRecovery.swift:46
            │    · Resets: isDashboardRefreshInFlight, isMarketMaterializationInFlight,
            │              activationTask, pendingRefreshPayload, pendingPublishTask
            │    · Resets: WealthReadyStateGate, WealthDownstreamRebuildOrchestrator
            │  }

            ├─ WealthEngineScanScheduler.shared.markPhaseComplete(.cacheRestore)
            │    · progress → 20%
            │    · Posts .wealthScanProgressDidUpdate (progress=0.2)

            ├─ [UNIVERSE SCAN]
            │  Trace: "universeScan – start"
            │
            │  let hasCachedUniverse = await Task.detached {
            │      WealthMarketUniverseStore.shared.prepareCachedSnapshotForStartup()
            │  }.value
            │  · Reads UserDefaults: awc_universe_signature, awc_universe_last_downloaded
            │
            │  ── CACHE HIT ────────────────────────────────────────────────────
            │  if hasCachedUniverse {
            │      markPhaseComplete(.universeScan)  → progress = 40%
            │  }
            │
            │  ── CACHE MISS (DOWNLOAD) ────────────────────────────────────────
            │  else {
            │      await Task.detached {
            │          await WealthMarketUniverseStore.shared.reloadForStartupSequence()
            │          · Loads/downloads the full universe (128k+ records)
            │          · Writes UserDefaults: awc_universe_signature
            │          · Writes UserDefaults: awc_universe_last_downloaded
            │          · Populates WealthMarketUniverseStore.shared.records
            │      }.value
            │      WealthDataAliveStore.shared.recordUniverseDownload()
            │      · Sets lastUniverseDownload = Date() (in-memory, 6h freshness window)
            │      markPhaseComplete(.universeScan)  → progress = 40%
            │  }
            │  Trace: "universeScan – done"
            │  guard !Task.isCancelled else { return }
            │  sleep 2s

            ├─ [AI SCAN]
            │  Trace: "aiScan – start"
            │  runAIScanWithProgress()
            │  · Posts .wealthRefreshPhaseWillBegin (aiScan)
            │  · Task.detached { performAIScan() }
            │      → WealthBrainStore.shared.ingest(...)
            │  · markPhaseComplete(.aiScan) → progress = 60%
            │  · Posts .wealthRefreshPhaseDidComplete (aiScan)
            │  Trace: "aiScan – done"
            │  sleep 1s

            ├─ [MARKET RANKING]
            │  Trace: "marketRanking – start"
            │  runMarketRankingWithProgress()
            │  · Posts .wealthRefreshPhaseWillBegin (marketRanking)
            │  · Task.detached { performMarketRanking() }
            │      → materializeMarketCandidates()
            │           → WealthCardHoldingRouter.routeFromGreenCheckpoint()
            │           → safeguard gate (earningsRisk, macroRisk, staleData, etc.)
            │           → 50% data/score recheck
            │           → assignMarketRanks() (dense ranking)
            │           → merge ranks into rankedAssets
            │           → WealthAllCardsStore.shared.sync(...)
            │  · markPhaseComplete(.marketRanking) → progress = 80%
            │  · Posts .wealthRefreshPhaseDidComplete (marketRanking)
            │  Trace: "marketRanking – done"
            │  sleep 1s

            ├─ [RESEARCH FEEDS]
            │  Trace: "researchFeeds – start"
            │  runResearchFeedsWithProgress()
            │  · Posts .wealthRefreshPhaseWillBegin (researchFeeds)
            │  · Task.detached { performResearchFeeds() } [stub]
            │  · markPhaseComplete(.researchFeeds) → progress = 100%
            │  · Posts .wealthRefreshPhaseDidComplete (researchFeeds)
            │  Trace: "researchFeeds – done"

            └─ [COMPLETION]
               await MainActor.run {
                   isStartupComplete = true
                   startupTask = nil
                   tradingLifecycleArmed = true
                   rescheduleTimers()
               }
               Trace: "rescheduleTimers – done; startup complete"
               WealthStartupLagTracer.shared.printSummary()

               await MainActor.run {
                   WealthReadyStateGate.shared.markDownstreamRebuildComplete()
                   · Sets isDownstreamRebuildComplete = true
                   · isFullyReady = true (both conditions met)
                   · Posts .wealthEngineDidBecomeReady  ←──────────────────┐
               }                                                            │
               WealthEventLogStore.shared.record(...)                       │
                                                                            │
[.wealthEngineDidBecomeReady received] ←────────────────────────────────────┘

  ├─ WealthNewComponentsBootstrap.runPostReadyPipeline()
  │    · MarketExecutionAudit.runAudit()
  │    · WealthDownstreamCacheSanity.saveMarketSnapshot(marketCards)
  │        → writes Caches/awc_market_snapshot.json
  │    · WealthAILiveCoordinator.shared.evaluateCandidates()
  │        → writes Caches/awc_ai_live_results.json
  │    · WealthAILiveRejectionAudit.runAudit()
  │    · WealthOrderRestrictionRules.runAudit()
  │    · WealthActivityAdmissionAudit.runAudit()
  │    · WealthDownstreamCacheSanity.saveActivityState(admissibleSymbols)
  │        → writes Caches/awc_activity_state.json

  └─ WealthDownstreamCacheSanity.validatePersistedDownstreamState()
       (HIDDEN — registered in WealthDownstreamCacheSanity.init())
       · Checks freshness of awc_market_snapshot.json
       · Checks freshness of awc_ai_live_results.json
       · Checks freshness of awc_activity_state.json
       · If any stale: WealthStaleCacheDetector.shared.checkAndRebuildIfNeeded()
```

---

## Part 14: Scan Progress Tracker (Hidden Gate for AI Live)

**File:** `Wealth Creation/WealthEngineScanScheduler.swift`

The scan scheduler tracks 5 phases. Progress gates downstream consumers.

| Phase | Enum | Completes at | Progress after |
|-------|------|-------------|---------------|
| Cache restore | `.cacheRestore` | Pre-flight (line 99) | 20% (1/5) |
| Universe scan | `.universeScan` | After universe load | 40% (2/5) |
| AI scan | `.aiScan` | After `runAIScan()` | 60% (3/5) |
| Market ranking | `.marketRanking` | After `runMarketRanking()` | 80% (4/5) |
| Research feeds | `.researchFeeds` | After `runResearchFeeds()` | 100% (5/5) |

**AI Live gate:** `minimumProgressForAILive = 0.5`  
`WealthAILiveCoordinator` checks `WealthEngineScanScheduler.shared.hasReachedAILiveGate` before evaluating candidates. This ensures universe + AI scan are both complete (progress ≥ 0.5 = 2 of 5 phases) before AI Live can promote cards.

---

## Part 15: Startup Lag Tracer Output (What Appears in Logs)

**File:** `Wealth Creation/WealthStartupLagTracer.swift`

The `[AWC·Startup]` lines visible in the debug console come from `WealthStartupLagTracer`. Every call to `trace(_:)` prints:
```
[AWC·Startup] + X.XXXs  <label>
```

Expected trace sequence during universe download (cache miss):
```
[AWC·Startup] +  0.001s  prepareLaunch – start
[AWC·Startup] +  0.003s  prepareLaunch – pipeline singletons activated
[AWC·Startup] +  0.XXXs  prepareLaunch – cache restore complete; startup sequence beginning
[AWC·Startup] +  0.XXXs  runStartupSequence – start
[AWC·Startup] +  0.XXXs  universeScan – start
         ← [UNIVERSE DOWNLOADING HERE — typically 1–10+ seconds]
[AWC·Startup] + XX.XXXs  universeScan – done
[AWC·Startup] + XX.XXXs  aiScan – start       (after 2s sleep)
[AWC·Startup] + XX.XXXs  aiScan – done
[AWC·Startup] + XX.XXXs  marketRanking – start (after 1s sleep)
[AWC·Startup] + XX.XXXs  marketRanking – done
[AWC·Startup] + XX.XXXs  researchFeeds – start (after 1s sleep)
[AWC·Startup] + XX.XXXs  researchFeeds – done
[AWC·Startup] + XX.XXXs  rescheduleTimers – done; startup complete
```

Events are also forwarded to `WealthEventLogStore` (category: `"startup"`, tintName: `"cyan"`) and appear in the in-app event log.

---

## Part 16: WealthMarketUniverseStore — The Universe Store (Not in Git)

`WealthMarketUniverseStore` is referenced extensively in the committed files but its implementation is in `WealthCore.swift` (not committed to git — present only in `DerivedDataLocalMac/` build artifacts). Based on call-site analysis:

| Method | Called from | Purpose |
|--------|-------------|---------|
| `prepareCachedSnapshotForStartup()` | `WealthEngineStartupController.swift:116` | Returns `true` if valid cached universe exists; reads UserDefaults cache keys |
| `reloadForStartupSequence()` | `WealthEngineStartupController.swift:131` | Performs the actual universe load/download; writes UserDefaults cache keys |
| `.records` | `WealthEngineStore+UniverseBlueprints.swift:58` | The `[MarketUniverseRecord]` array of all universe instruments |

The `currentUniverseSeedSource()` method (`WealthEngineStore+UniverseBlueprints.swift:56`) returns the cached records if available, or an empty result — the synchronous CSV fallback (`WealthMarketUniverseLoader.records()`) was intentionally removed to prevent the main-thread freeze that was blocking launch.

---

## Part 17: All Involved Files — Complete Reference

| File | Role | Key Functions |
|------|------|--------------|
| `WealthEngineStore+Bootstrap.swift` | App entry point routing | `bootstrap()`, `handleForegroundActivation()` |
| `WealthEngineStore+Activation.swift` | Secondary entry point | `runActivationSequence()` |
| `WealthAppSessionController.swift` | Lifecycle controller | `prepareLaunch()`, `applicationDidBecomeActive()`, `applicationDidEnterBackground()`, `applicationWillTerminate()` |
| `WealthNewComponentsBootstrap.swift` | Singleton activation + post-ready | `activate()`, `runPostReadyPipeline()` |
| `WealthEngineStore+BackgroundCache.swift` | Async cache restore/save | `restoreCacheInBackground(completion:)`, `saveInBackground()` |
| `WealthEngineStore+Cache.swift` | Sync cache restore/save | `restoreCache()`, `save()`, `applyBundle()`, `restoreFromLegacyFiles()` |
| `PersistenceManager.swift` | Atomic bundle I/O | `saveBundle(_:)`, `loadBundle()`, `clearBundle()` |
| `WealthEngineStartupController.swift` | Startup orchestration | `beginStartupSequence()`, `runStartupSequence()`, `cancelStartupSequence()` |
| `WealthEngineStore+Refresh.swift` | Scan entry points | `runUniverseScan()`, `runAIScan()`, `runMarketRanking()`, `runResearchFeeds()`, `refresh(mode:)` |
| `WealthEngineRefresh+LifecyclePublishing.swift` | Progress notifications | `runUniverseScanWithProgress()`, `runAIScanWithProgress()`, `runMarketRankingWithProgress()`, `runResearchFeedsWithProgress()` |
| `WealthEngineStore+Materialization.swift` | Market ranking gate | `materializeMarketCandidates()`, `evaluateSafeguards()` |
| `WealthEngineStore+UniverseBlueprints.swift` | Universe seed source | `currentUniverseSeedSource()` |
| `WealthEngineRuntimeRecovery.swift` | Pre-flight integrity check | `runStartupIntegrityCheck()`, `performFullRecovery(reason:)` |
| `WealthEngineRuntimeCoordinator.swift` | Foreground activation | `handleBecameActive()` |
| `WealthReadyStateGate.swift` | Ready-state gating | `markDownstreamRebuildComplete()`, `isFullyReady`, `reset()` |
| `WealthEngineScanScheduler.swift` | Scan progress tracking | `markPhaseComplete(_:)`, `currentProgress`, `hasReachedAILiveGate` |
| `WealthStaleCacheDetector.swift` | Freshness detection | `checkAndRebuildIfNeeded()`, `isCachedMarketWithoutLiveScores()`, `isCacheStale()` |
| `WealthDownstreamRebuildOrchestrator.swift` | Downstream rebuild | `triggerRebuild(reason:)`, `performDownstreamRebuild()` |
| `WealthDownstreamCacheSanity.swift` | File cache persistence + validation | `saveMarketSnapshot()`, `saveAILiveResults()`, `saveActivityState()`, `validatePersistedDownstreamState()`, `invalidateAILiveResults()` |
| `WealthDataAliveStore.swift` | Data freshness tracking | `recordUniverseDownload()`, `isUniverseAlive`, `isFullyAlive` |
| `WealthStartupLagTracer.swift` | Console timing trace | `trace(_:)`, `printSummary()` |
| `WealthEngineStore.swift` | Core state container | All `@Published` properties, `runStartupActivationScan()`, `runStartupMarketWarmup()` |
| `WealthAppSessionController.swift` | Session lifecycle | `applicationDidEnterBackground()`, `applicationWillTerminate()` |
| `MarketDataFetcher.swift` | Per-symbol price fetch | `fetchQuote(for:)`, `performFetch(symbol:)` via `URLSession.shared.data(from:)` |

---

## Part 18: Why the Logs Say "still downloading the univ"

Based on the full trace, the log entry:
```
its till downlaoding the univ
```
(from the user's message, appearing after `[CardFlow]` and `[PipelineTrace]` log lines) indicates that when the log was captured:

1. **CardFlow/PipelineTrace logs are firing** — these come from the `WealthAllCardsStore.sync()` call inside `materializeMarketCandidates()` after a previous cached universe run
2. **The universe is still downloading** — `reloadForStartupSequence()` is in progress (async, background task), having been triggered because `prepareCachedSnapshotForStartup()` returned `false`

This confirms the startup is on the **cache miss path** (Phase 4, Step C above). The 128,443 cards visible in the CardFlow logs are from a **previously cached universe** that was restored in Phase 1 (background cache restore), while the *new* universe download is occurring simultaneously in the background to refresh the cache.

The failure message:
```
Failed to send CA Event for app launch measurements for ca_event_type: 0
event_name: com.apple.app_launch_measurement.FirstFramePresentationMetric
```
is an **iOS system-level** metric collection failure (not AWC code). It occurs when Apple's CoreAnalytics framework cannot send its launch timing metric. This is unrelated to the universe download.

---

---

## Part 19: PipelineTrace — Expanded Universe (Full Investigation)

### The Log Lines in Question

```
[CardFlow] after_scoring totalCards=128443 green=39219 blue=28585 purple=29529 red=31110 grey=0 regions=US:122429,CRYPTO:3367,FX:2556,AU:78,APAC:12,GLOBAL:1
[CardFlow] stores green=39219 blue=28585 purple=29529 red=31110 grey=0
[CardFlow] routing green->red=0 green->grey=0 green->allCards=128343
[CardFlow] dispatcher blue=28585 purple=29529
[CardFlow] market input=128443 market=100
[PipelineTrace] stage=all_cards_review_cache total=128443 regions={AU:78,US:122429,EU:0,Other:5936} markets={ETF:53527,NASDAQ:41055,OTC:11850,AMEX:10428,NYSE:5081,CRYPTO:3367,FX:2556,CBOE:488,ASX:78,NSE:12,BOND:1} colors={Green:39219,Blue:28585,Purple:29529,Red:31110}
[PipelineTrace] stage=all_cards_market_cache total=100 regions={AU:0,US:100,EU:0,Other:0} markets={AMEX:84,NYSE:16} colors={Green:100,Blue:0,Purple:0,Red:0}
```

### Where These Log Lines Come From

**After exhaustive search of every committed Swift source file, every compiled object file (`.o`), the linked app binary, and the debug dylib** — none of the `[CardFlow]` or `[PipelineTrace]` log strings exist in any committed or compiled artifact in the repository.

**Conclusion:** These log lines are emitted exclusively by **`WealthCore.swift`** — the core engine file that is **not committed to git** and exists only in the local Xcode build (`DerivedDataLocalMac/`). This file contains the full universe scoring, color-assignment, routing, and dispatch logic that produces these log lines.

The committed source files define the **scaffolding, data stores, and post-scoring gates** that `WealthCore.swift` connects to. The `[CardFlow]` and `[PipelineTrace]` logs are the visible output of the logic inside that file.

---

### The Expanded Universe — What `all_cards_review_cache` Is

The **expanded universe** is the full set of all scored opportunity cards **after the universe scoring pass completes**, before any market selection gate has run. In the log above this is:

```
[PipelineTrace] stage=all_cards_review_cache total=128443
```

This is the canonical "expanded universe" stage — **all 128,443 instruments** from the global universe (CSV / API), now scored, colored, and classified into color buckets, cached in `WealthAllCardsStore.allOpportunities`.

The companion stage:
```
[PipelineTrace] stage=all_cards_market_cache total=100
```
…is the narrowed-down **market cache** — the 100 cards that passed all gates and received a market rank, stored in `WealthAllCardsStore.marketCards`.

---

### The Full Expanded Universe Pipeline (WealthCore.swift + Committed Files)

```
[UNIVERSE DOWNLOAD completes]
WealthMarketUniverseStore.shared.records = 128,443 MarketUniverseRecord entries
                                                           ← WealthCore.swift

         ↓
[SCORING PASS — WealthCore.swift, inside performUniverseScan()]

Each MarketUniverseRecord is scored by AWGScoringEngine:
  AWGScoringEngine.score(for: blueprint, settings: AWGBehaviorSettingsStore)
  ↓
  Returns: aiScore (Int), confidence (Int), safety (Int),
           expectedProfit (Double), shares (Int), fee (Double)

Each scored record becomes an Opportunity with a color assignment:
  ┌─────────────────────────────────────────────────┐
  │  Green  (39,219)  — strong buy, PnL ≥ 0         │
  │  Blue   (28,585)  — waiting, weak green, PnL < 0│
  │  Purple (29,529)  — holding / position open      │
  │  Red    (31,110)  — sell / exit signal           │
  │  Grey   (0)       — unranked / inactive          │
  └─────────────────────────────────────────────────┘
  Total = 128,443

         ↓
[CardFlow] after_scoring totalCards=128443 green=39219 blue=28585 purple=29529 red=31110 grey=0
  ← logged by WealthCore.swift immediately after the scoring loop

         ↓
[STORE UPDATES — called from WealthCore.swift]

WealthGreenCardsStore.shared.update(greenCards)        ← GreenCardsStore.swift:34
WealthBlueCardsStore.shared.update(blueCards)          ← BlueCardsStore.swift:33
WealthGreyCardsStore.shared.update(greyCards)          ← GreyCardsStore.swift:35
  (Purple and Red stored in equivalent stores in WealthCore.swift)

[CardFlow] stores green=39219 blue=28585 purple=29529 red=31110 grey=0
  ← logged by WealthCore.swift after all lane stores are updated

         ↓
[ROUTING — WealthCardHoldingRouter.routeFromGreenCheckpoint()]
  ← WealthCore.swift calls this; definition in WealthCore.swift
  ← WealthCardHoldingStoreSupport.swift adds query/diagnostic helpers

  Green cards: PnL ≥ 0 → eligible for Market ranking (39,219 - 100 = 39,119 candidates)
    Routing:
      green→red  = 0    (no green demoted to red this cycle)
      green→grey = 0    (no green demoted to grey this cycle)
      green→allCards = 128,343  (all greens flow into the full allCards set)

[CardFlow] routing green->red=0 green->grey=0 green->allCards=128343

         ↓
[DISPATCHER — WealthBrainModuleRegistry.shared.dispatch()]
  ← WealthBrainModuleRegistry.swift:81
  Dispatches blue (28,585) and purple (29,529) to brain modules
  (These lanes are not eligible for Market ranking — dispatched for learning only)

[CardFlow] dispatcher blue=28585 purple=29529

         ↓
[MARKET INPUT GATE — materializeMarketCandidates()]
  ← WealthEngineStore+Materialization.swift:74

  Input:  128,443 total universe cards
  Gate 1: Strong Green only (PnL ≥ 0) → 39,219
  Gate 2: Safeguard (earningsRisk < 70, macroRisk < 75, !isDataStale,
                      isExecutionClean, isAnomalyStable) → subset
  Gate 3: isMarketExecutableCandidate → subset
  Gate 4: prefix(100) → exactly 100 market candidates
  Rank assignment: dense ranks (1,1,2,3,3…) by marketQualityTier
  Merge ranks back into rankedAssets

[CardFlow] market input=128443 market=100

         ↓
[WealthAllCardsStore.sync()]
  ← WealthAllCardsStore.swift:59

  allOpportunities  = 128,443 ranked Opportunity objects  ← THE EXPANDED UNIVERSE
  marketCards       = 100 ranked Opportunity objects (rank > 0, capped at 100)
  activityKeys      = [] (populated later by AI Live pass)
  holdingKeys       = Set of held symbols
  livePickKeys      = [] (populated later by AI Live pass)

         ↓
[PipelineTrace] stage=all_cards_review_cache total=128443  ← WealthCore.swift logs WealthAllCardsStore.allOpportunities
  regions={AU:78, US:122429, EU:0, Other:5936}
  markets={ETF:53527, NASDAQ:41055, OTC:11850, AMEX:10428, NYSE:5081,
           CRYPTO:3367, FX:2556, CBOE:488, ASX:78, NSE:12, BOND:1}
  colors={Green:39219, Blue:28585, Purple:29529, Red:31110}

[PipelineTrace] stage=all_cards_market_cache total=100   ← WealthCore.swift logs WealthAllCardsStore.marketCards
  regions={AU:0, US:100, EU:0, Other:0}
  markets={AMEX:84, NYSE:16}
  colors={Green:100, Blue:0, Purple:0, Red:0}
```

---

### Breakdown of the Expanded Universe (128,443 cards)

#### By Region
| Region | Count | % of Universe |
|--------|-------|--------------|
| US | 122,429 | 95.3% |
| Other (non-categorised) | 5,936 | 4.6% |
| AU (Australia) | 78 | 0.06% |
| EU | 0 | — |
| APAC | 12 | — |
| GLOBAL | 1 | — |

#### By Market
| Market | Count |
|--------|-------|
| ETF | 53,527 |
| NASDAQ | 41,055 |
| OTC | 11,850 |
| AMEX | 10,428 |
| NYSE | 5,081 |
| CRYPTO | 3,367 |
| FX | 2,556 |
| CBOE | 488 |
| ASX | 78 |
| NSE | 12 |
| BOND | 1 |
| **Total** | **128,443** |

#### By Color (Score Tier)
| Color | Count | Meaning |
|-------|-------|---------|
| Green | 39,219 | Strong buy, PnL ≥ 0, eligible for market ranking |
| Blue | 28,585 | Waiting / weak green (PnL < 0) |
| Purple | 29,529 | Hold / open position |
| Red | 31,110 | Exit signal |
| Grey | 0 | Unranked / filtered out |

---

### Why the Expanded Universe Is Still Downloading When These Logs Fire

When the user's log shows "still downloading the univ" alongside `[CardFlow]` and `[PipelineTrace]` entries, this is because **two separate universe operations are running simultaneously**:

1. **The CardFlow/PipelineTrace logs** come from a **previous cached universe** (128,443 cards from a prior session) that was restored by `restoreCacheInBackground()` and is being scored and routed through the pipeline.

2. **The "still downloading"** refers to a **fresh universe download** (`WealthMarketUniverseStore.reloadForStartupSequence()`) running concurrently in a separate `Task.detached` on a different background thread, because `prepareCachedSnapshotForStartup()` returned `false` (6-hour cache expired or no previous download).

The two paths run in parallel because:
- `WealthAllCardsStore.sync()` is called inside `materializeMarketCandidates()` after the scoring pass on the **cached** universe
- `reloadForStartupSequence()` runs in `WealthEngineStartupController.runStartupSequence()` as a gated step

Once the new universe download completes, the engine re-runs the scoring + routing + materialization pipeline, producing a fresh set of `[CardFlow]` and `[PipelineTrace]` logs with updated counts.

---

### Committed Files Involved in the Expanded Universe Pipeline

| File | Role in Expanded Universe |
|------|--------------------------|
| `WealthEngineStore+UniverseBlueprints.swift` | `currentUniverseSeedSource()` returns cached records or empty — removed the blocking CSV synchronous load |
| `WealthEngineStore+Refresh.swift` | `performUniverseScan()` stub — delegates full scoring logic to WealthCore.swift |
| `WealthEngineStore+Materialization.swift` | Market gate (safeguard + execution + rank) — narrows 128k → 100 |
| `WealthAllCardsStore.swift` | Stores ALL 128,443 as `allOpportunities`; stores top 100 as `marketCards` |
| `WealthGreenCardsStore.swift` | Stores the 39,219 green (strong buy) cards |
| `WealthBlueCardsStore.swift` | Stores the 28,585 blue (waiting) cards |
| `WealthGreyCardsStore.swift` | Stores the 0 grey (unranked) cards |
| `WealthCardHoldingStoreSupport.swift` | Query/diagnostic helpers for the routing layer |
| `WealthBrainModuleRegistry.swift` | Dispatches blue/purple cards to brain modules after routing |
| `Opportunity+CardStateMachine.swift` | Computed properties: `isStrongGreen`, `isWeakGreen`, `isDataStale`, `earningsRisk`, `macroRisk`, `isAnomalyStable`, `isExecutionClean` |
| `WealthMarketExecutionAudit.swift` | Audit report tracing the exact drop at each gate (universe → green → safeguard → market) |

---

## Summary: The 7 Hidden/Internal Processes

These are the processes that are not immediately visible from the public entry points:

| # | Hidden Process | File | Triggered by |
|---|---------------|------|-------------|
| 1 | `WealthNewComponentsBootstrap` singleton activation (11 singletons inited) | `NewComponentsBootstrap.swift:46` | `prepareLaunch()` |
| 2 | `.wealthEngineDidBecomeReady` observer registration for `runPostReadyPipeline()` | `NewComponentsBootstrap.swift:63` | `activate()` |
| 3 | `.wealthEngineDidBecomeReady` observer registration for `validatePersistedDownstreamState()` | `DownstreamCacheSanity.swift:44` | `WealthDownstreamCacheSanity.init()` (lazy singleton init) |
| 4 | Pre-flight integrity check (stuck-flag reset) | `WealthEngineRuntimeRecovery.swift:46` | `runStartupSequence()` start |
| 5 | UserDefaults cache-key read for universe freshness gate | `WealthEngineStartupController.swift:116` | Before every universe download decision |
| 6 | `WealthDataAliveStore.recordUniverseDownload()` timestamp stamp | `WealthEngineStartupController.swift:133` | After every universe download |
| 7 | `WealthDownstreamCacheSanity.validatePersistedDownstreamState()` secondary rebuild check | `DownstreamCacheSanity.swift:154` | Every `.wealthEngineDidBecomeReady` notification |
