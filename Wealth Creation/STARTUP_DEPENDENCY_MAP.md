# AWC Startup Dependency Map

Complete trace of every feature, side-effect, property, and component that
is triggered by — or depends on — the startup system.

---

## 1. Entry Points

### 1.1 Cold Start (first launch / app install)

```
ContentView.onAppear
  └─ WealthEngineStore.bootstrap()                           [Bootstrap.swift]
       └─ WealthAppSessionController.prepareLaunch()         [SessionController.swift]
            ├─ WealthNewComponentsBootstrap.activate()       [activates all singletons]
            └─ WealthEngineStore.restoreCacheInBackground {  [BackgroundCache.swift]
                 WealthEngineStartupController
                   .beginStartupSequence()                   [StartupController.swift]
               }
```

`prepareLaunch()` is guarded by `hasLaunched: Bool` — **idempotent**, safe to
call from scene reconnects.

### 1.2 Warm Open / Unlock (app returns from background)

```
ContentView.onChange(scenePhase == .active)
  └─ WealthEngineStore.handleForegroundActivation()          [Bootstrap.swift]
       └─ WealthAppSessionController
            .applicationDidBecomeActive()                    [SessionController.swift]
               └─ WealthEngineRuntimeCoordinator
                    .handleBecameActive()                    [RuntimeCoordinator.swift]
                         ├─ [GUARD] isStartupComplete?
                         │   NO  → no-op (startup still running)
                         │   YES → WealthSessionUnlockController
                         │              .handleSessionResume()
                         └─ debounce: minimumResumeDebounceSecs = 2 s
```

### 1.3 Background Transition

```
ContentView.onChange(scenePhase == .background)
  └─ WealthAppSessionController
       .applicationDidEnterBackground()
            ├─ WealthSessionUnlockController.cancelSessionResume()
            └─ WealthEngineStore.saveInBackground()          [BackgroundCache.swift]
```

### 1.4 App Terminate

```
applicationWillTerminate
  └─ WealthAppSessionController.applicationWillTerminate()
       └─ WealthEngineStore.save()                           [Cache.swift – synchronous]
```

---

## 2. WealthNewComponentsBootstrap.activate()

Called once at launch.  Touches every new singleton so their `init()` runs
and NotificationCenter observers register.

| Singleton activated | Observer registered for |
|---|---|
| `WealthDownstreamCacheSanity` | `wealthEngineDidBecomeReady` → `validatePersistedDownstreamState()` |
| `WealthMarketExecutionAudit` | — |
| `WealthAILiveRejectionAudit` | — |
| `WealthActivityAdmissionAudit` | — |
| `WealthEngineScanScheduler` | — |
| `WealthEngineRuntimeCoordinator` | — |
| `WealthEngineRuntimeRecovery` | — |
| `WealthAILiveCoordinator` | — |
| `WealthOrderRestrictionRules` | — |
| `WealthPortfolioLifecycleHelper` | `wealthEngineDidBecomeReady` → `handleEngineReady()` |

Additionally registers a **post-ready pipeline** observer:

```
wealthEngineDidBecomeReady
  └─ WealthNewComponentsBootstrap.runPostReadyPipeline()
       ├─ WealthMarketExecutionAudit.runAudit(on: rankedAssets)
       ├─ WealthDownstreamCacheSanity.saveMarketSnapshot(marketCards)
       ├─ WealthAILiveCoordinator.evaluateCandidates()
       ├─ WealthAILiveRejectionAudit.runAudit(on: marketCards)
       ├─ WealthOrderRestrictionRules.runAudit(on: promotedCards)
       ├─ WealthActivityAdmissionAudit.runAudit(on: promotedCards)
       └─ WealthDownstreamCacheSanity.saveActivityState(admissibleSymbols)
```

---

## 3. Cache Restore Phase

### 3.1 restoreCacheInBackground(completion:)   [BackgroundCache.swift]

Runs entirely on `Task.detached(priority: .userInitiated)`.  Decodes large
arrays **off the main thread**.  Hops to `@MainActor` only for property
assignment.

Properties written on main actor:

| Property | Type | UI/Feature it drives |
|---|---|---|
| `lastRefresh` | `Date?` | Dashboard refresh time label |
| `lastHeavyRefresh` | `Date?` | Staleness detection in `WealthStaleCacheDetector` |
| `rankedAssets` | `[Opportunity]` | Dashboard card list, market ranking, AI Live candidates |
| `scannedSignals` | `[MarketSignal]` | AI brain input for next scan |
| `holdings` | `[Holding]` | Portfolio value, P/L calculations, card routing |

Cache files (Caches directory):

| File | Contains |
|---|---|
| `awc_engine_ranked_assets.json` | Full scored opportunity set |
| `awc_engine_scanned_signals.json` | Last AI brain signal set |
| `awc_engine_holdings.json` | Portfolio positions |

UserDefaults keys (lightweight only):

| Key | Contains |
|---|---|
| `awc_engine_last_refresh` | Timestamp of last soft refresh |
| `awc_engine_last_heavy_refresh` | Timestamp of last deep refresh |

### 3.2 WealthEngineScanScheduler.markPhaseComplete(.cacheRestore)

Called immediately after `restoreCacheInBackground` completes (inside
`WealthEngineStartupController.runStartupSequence()`).  Updates:

- `completedPhases: Set<ScanPhase>`
- `currentProgress: Double` — advances from 0 to 0.2 (1 of 5 phases)
- Posts `Notification.Name.wealthScanProgressDidUpdate`

---

## 4. Startup Sequence (WealthEngineStartupController)

`beginStartupSequence()` is guarded by `startupTask == nil && !isStartupComplete`.

### 4.1 Pre-flight: Integrity Check

```
WealthEngineRuntimeRecovery.shared.runStartupIntegrityCheck()
```

Resets stuck state from a previous interrupted session:

| Flag / Handle checked | Reset action |
|---|---|
| `isDashboardRefreshInFlight == true` | → `false` |
| `isMarketMaterializationInFlight == true` | → `false` |
| `activationTask != nil` | → `nil` |
| `pendingRefreshPayload != nil` | → `nil` |
| `pendingPublishTask != nil` | → `nil` |
| `WealthReadyStateGate` | `reset()` → `isDownstreamRebuildComplete = false` |
| `WealthDownstreamRebuildOrchestrator` | `cancelRebuild()` |

### 4.2 Step 1 — Universe Scan

```
runUniverseScanWithProgress()                        [LifecyclePublishing.swift]
  ├─ posts: wealthRefreshPhaseWillBegin(.universeScan)
  ├─ runUniverseScan()                               [Refresh.swift]
  │    └─ Task.detached → performUniverseScan()      [WealthCore.swift stub]
  ├─ WealthEngineScanScheduler.markPhaseComplete(.universeScan)
  │    → currentProgress = 0.4 (2 of 5)
  │    → posts wealthScanProgressDidUpdate
  └─ posts: wealthRefreshPhaseDidComplete(.universeScan)
```

Side effects:
- Populates `rankedAssets` with the scored universe.
- `WealthMarketUniverseStore.prepareCachedSnapshotForStartup()` is called
  first — reuses on-device cache if valid; calls `reloadForStartupSequence()`
  (async CSV load) only when no cache exists.

Sleep: **2 seconds** between universe scan and AI scan.

### 4.3 Step 2 — AI Scan

```
runAIScanWithProgress()
  ├─ posts: wealthRefreshPhaseWillBegin(.aiScan)
  ├─ runAIScan()
  │    └─ Task.detached → performAIScan()            [populates aiScore on cards]
  ├─ WealthEngineScanScheduler.markPhaseComplete(.aiScan)
  │    → currentProgress = 0.6 (3 of 5)
  │    → hasReachedAILiveGate = true  ← AI Live promotion is now UNBLOCKED
  │    → posts wealthScanProgressDidUpdate
  └─ posts: wealthRefreshPhaseDidComplete(.aiScan)
```

Side effects:
- `aiScore` and `confidence` populated on every `Opportunity`.
- `WealthEngineScanScheduler.hasReachedAILiveGate` flips to `true`,
  unblocking `WealthAILiveCoordinator.evaluateCandidates()`.

Sleep: **1 second** between AI scan and market ranking.

### 4.4 Step 3 — Market Ranking

```
runMarketRankingWithProgress()
  ├─ posts: wealthRefreshPhaseWillBegin(.marketRanking)
  ├─ runMarketRanking()
  │    └─ Task.detached → performMarketRanking()
  │         └─ materializeMarketCandidates()         [Materialization.swift]
  │              ├─ [GUARD] isMarketMaterializationInFlight
  │              ├─ WealthCardHoldingRouter.routeFromGreenCheckpoint(rankedAssets)
  │              │    ├─ Strong Green (unrealizedPnL ≥ 0) → eligible for ranking
  │              │    └─ Weak Green   (unrealizedPnL < 0) → Blue waiting list
  │              ├─ selectExecutableCandidates()
  │              │    ├─ evaluateSafeguards() per card:
  │              │    │    earningsRisk ≥ 70 → rejected
  │              │    │    macroRisk    ≥ 75 → rejected
  │              │    │    isDataStale       → rejected
  │              │    │    !isExecutionClean → rejected
  │              │    │    !isAnomalyStable  → rejected
  │              │    └─ filter isMarketExecutableCandidate
  │              │         capped at WealthAllCardsStore.marketCardLimit (100)
  │              ├─ applyDataRecheck()  — 50 % freshness re-check
  │              ├─ assignMarketRanks() — dense rank by marketQualityTier
  │              └─ WealthAllCardsStore.shared.sync(...)
  ├─ WealthEngineScanScheduler.markPhaseComplete(.marketRanking)
  │    → currentProgress = 0.8 (4 of 5)
  └─ posts: wealthRefreshPhaseDidComplete(.marketRanking)
```

Side effects:
- `rank` property set on top-100 executable green cards.
- `WealthAllCardsStore` synced — drives card-list UI.

Sleep: **1 second** between market ranking and research feeds.

### 4.5 Step 4 — Research Feeds

```
runResearchFeedsWithProgress()
  ├─ posts: wealthRefreshPhaseWillBegin(.researchFeeds)
  ├─ runResearchFeeds()
  │    └─ Task.detached → performResearchFeeds()     [appends intel to ranked cards]
  ├─ WealthEngineScanScheduler.markPhaseComplete(.researchFeeds)
  │    → currentProgress = 1.0 (5 of 5 — fully complete)
  └─ posts: wealthRefreshPhaseDidComplete(.researchFeeds)
```

### 4.6 Startup Completion

```
isStartupComplete = true
startupTask = nil
WealthEngineStore.shared.rescheduleTimers()          ← starts recurring timers
WealthEventLogStore.shared.record(...)               ← "Startup sequence complete"
```

---

## 5. Recurring Timer Schedule   [Timers.swift]

Timers are started **after** the startup sequence completes.
All timer callbacks dispatch to `Task.detached(priority: .userInitiated)`.

| Timer | Interval | Refresh mode | Purpose |
|---|---|---|---|
| IBKR timer 1 | 9 min | `.ibkr` | Live price/broker update |
| Soft timer 1 (`softTimer`) | 10 min | `.soft` | Light: universe + AI + market |
| IBKR timer 2 | 19 min | `.ibkr` | Live price/broker update |
| Soft timer 2 (in `timerHolder`) | 20 min | `.soft` | Light refresh |
| IBKR timer 3 | 29 min | `.ibkr` | Live price/broker update |
| Deep timer (`heavyTimer`) | 30 min | `.deep` | Heavy: everything + research |

### Refresh Mode Pipelines

```
.ibkr  → runIBKRPriceSync()  → performIBKRSync()
.soft  → runUniverseScan() → runAIScan() → runMarketRanking()
.deep  → runUniverseScan() → runAIScan() → runMarketRanking() → runResearchFeeds()
```

### Timer Storage Strategy

Swift extensions cannot add stored properties.  A file-private
`WealthTimerHolder` class stores the overflow timer references:

```swift
timerHolder.ibkrTimers        // [Timer]  — three IBKR timers
timerHolder.extraSoftTimers   // [Timer]  — second soft timer (20 m)
WealthEngineStore.softTimer   // Timer?   — first soft timer (10 m)
WealthEngineStore.heavyTimer  // Timer?   — deep timer (30 m)
```

`rescheduleTimers()` calls `invalidateTimers()` first, then
`scheduleRecurringTimers()`.

`invalidateTimers()` invalidates all six timers and removes all references.

---

## 6. Downstream Rebuild Pipeline

### 6.1 Trigger (WealthStaleCacheDetector)

Called by `WealthSessionUnlockController.handleSessionResume()` on every
warm open / unlock.  Runs four checks; any failure triggers rebuild:

| Check | Condition |
|---|---|
| `isCachedMarketWithoutLiveScores()` | `rankedAssets` non-empty but all `aiScore == 0` |
| `isCacheStale()` | `lastRefresh` older than 5 minutes |
| `isAILiveResultsStale()` | AI Live results file missing or > 30 min old |
| `isActivityStateStale()` | Activity state file missing or > 30 min old |

If stale AI Live results are detected, `invalidateAILiveResults()` clears the
file so the UI shows all Market cards without stale exclusions while the fresh
rebuild runs.

Even when all checks pass, a lightweight rebuild is triggered with reason
`"session-resume"` so Activity always re-evaluates after unlock.

### 6.2 Orchestration (WealthDownstreamRebuildOrchestrator)

Guarded by `rebuildTask == nil`.

```
triggerRebuild(reason:)
  └─ performDownstreamRebuild()
       ├─ runAIScan()          — re-scores all ranked cards
       ├─ runMarketRanking()   — re-ranks; updates WealthAllCardsStore
       └─ WealthReadyStateGate.shared.markDownstreamRebuildComplete()
            └─ isFullyReady = true → posts wealthEngineDidBecomeReady
```

### 6.3 Ready-State Gate (WealthReadyStateGate)

`isFullyReady` requires **both**:
1. `WealthEngineStartupController.isStartupComplete == true`
2. `isDownstreamRebuildComplete == true`

On first transition to `isFullyReady`, posts:
`Notification.Name.wealthEngineDidBecomeReady`

### 6.4 Post-Ready Actions (triggered by wealthEngineDidBecomeReady)

Three observers fire on this notification:

**WealthNewComponentsBootstrap** (registered in `activate()`):
```
runPostReadyPipeline()
  ├─ WealthMarketExecutionAudit.runAudit(on: rankedAssets)
  ├─ WealthDownstreamCacheSanity.saveMarketSnapshot(marketCards)
  ├─ WealthAILiveCoordinator.evaluateCandidates()
  │    ├─ [GUARD] WealthEngineScanScheduler.hasReachedAILiveGate
  │    ├─ WealthAILiveRejectionAudit.runAudit(on: marketCards)
  │    ├─ filters: aiScore > 0, !isDataStale, isAnomalyStable,
  │    │           earningsRisk < 70, macroRisk < 75,
  │    │           rank ≤ topTierRankThreshold (default 3)
  │    ├─ sets promotedCards
  │    └─ WealthDownstreamCacheSanity.saveAILiveResults(eligible)
  ├─ WealthAILiveRejectionAudit.runAudit(on: marketCards)
  ├─ WealthOrderRestrictionRules.runAudit(on: promotedCards)
  ├─ WealthActivityAdmissionAudit.runAudit(on: promotedCards)
  └─ WealthDownstreamCacheSanity.saveActivityState(admissibleSymbols)
```

**WealthDownstreamCacheSanity** (registered in `init()`):
```
validatePersistedDownstreamState()
  └─ if any cache stale → WealthStaleCacheDetector.checkAndRebuildIfNeeded()
```

**WealthPortfolioLifecycleHelper** (registered in `init()`):
```
handleEngineReady()
  ├─ if tradingLifecycleArmed → triggerAdmissionRerun()
  │    └─ WealthPortfolioStore.rerunActivityAdmissionAfterStartup()
  │         ├─ WealthActivityAdmissionAudit.runAudit(on: promotedCards)
  │         └─ reconcileActivityAdmissions()
  └─ else → scheduleArmedRetry(attemptsRemaining: 30)
            polls every 1 second, up to 30 attempts
```

---

## 7. Recovery Paths

### 7.1 Startup Integrity Check   [RuntimeRecovery.swift]

Called at the START of every startup sequence (before phase 1).
Resets any stuck state left by a previous interrupted session.
See Section 4.1 for full details.

### 7.2 Session Resume Recovery   [SessionUnlockController.swift]

Triggered on every warm open / unlock (after startup is complete).

```
handleSessionResume()
  └─ performSessionResume()
       ├─ [GUARD] WealthEngineStartupController.isStartupComplete
       └─ WealthStaleCacheDetector.checkAndRebuildIfNeeded()
```

### 7.3 Full Recovery   [RuntimeRecovery.swift]

For unrecoverable corruption, decode failures, sign-out, factory reset.

```
performFullRecovery(reason:)
  ├─ WealthDownstreamRebuildOrchestrator.cancelRebuild()
  ├─ WealthSessionUnlockController.cancelSessionResume()
  ├─ WealthReadyStateGate.reset()
  └─ WealthEngineStore.recoverFromFailedRefresh(reason:)
       ├─ isDashboardRefreshInFlight = false
       ├─ isMarketMaterializationInFlight = false
       ├─ activationTask = nil
       ├─ pendingRefreshPayload = nil
       ├─ pendingPublishTask = nil
       └─ restoreCache()          ← last-known-good snapshot
```

### 7.4 Factory Reset   [Recovery.swift]

```
resetToFactoryDefaults()
  ├─ WealthEngineStartupController.cancelStartupSequence()
  ├─ invalidateTimers()
  ├─ [clear all engine flags]
  ├─ rankedAssets = []
  ├─ scannedSignals = []
  ├─ holdings = []
  ├─ lastRefresh = nil
  ├─ lastHeavyRefresh = nil
  └─ clearPersistedCache()
       ├─ remove UserDefaults keys
       ├─ remove awc_engine_ranked_assets.json
       ├─ remove awc_engine_scanned_signals.json
       ├─ remove awc_engine_holdings.json
       └─ WealthDownstreamCacheSanity.invalidateAllFileCaches()
            ├─ awc_ai_live_results.json
            ├─ awc_market_snapshot.json
            └─ awc_activity_state.json
```

---

## 8. IBKR Bridge Integration   [IBKRBridge.swift, IBKRBridge+Send.swift]

### 8.1 Connection Lifecycle

```
WealthIBKRBridge.connect(host:port:)
  ├─ NWConnection setup (TCP)
  ├─ emit(.connecting)
  ├─ startReceiving()           ← async receive loop
  └─ on state .ready → sendGreeting()
       └─ "API\0" + version range (raw bytes, no length prefix)
            └─ on handshake response → sendStartAPI()
                 └─ START_API (msgID=71) clientId=0
                      → apiReady = true
                      → emit(.connected)
```

### 8.2 Timer-Triggered IBKR Refreshes

At 9-minute, 19-minute, and 29-minute marks, `refresh(mode: .ibkr)` fires:

```
refresh(mode: .ibkr)
  └─ runIBKRPriceSync()
       └─ performIBKRSync()    [price-only sync via WealthIBKRBridge]
```

### 8.3 Market Data Subscriptions

```
WealthIBKRBridge.subscribeMarketData(contract:)
  └─ sends REQ_MKT_DATA (msgID=1) → returns requestID
WealthIBKRBridge.cancelMarketData(requestID:)
  └─ sends CANCEL_MKT_DATA (msgID=2)
```

Quotes are delivered as `WealthIBKRBridgeEvent.quote(WealthBrokerQuote)` to
registered event handlers.

---

## 9. Market Materialization   [Materialization.swift]

### 9.1 Safeguard Gate Thresholds

| Rule | Threshold | Rejection reason |
|---|---|---|
| Earnings risk | ≥ 70 | `.earningsRisk` |
| Macro risk | ≥ 75 | `.macroRisk` |
| Data quality | contains "stale" | `.staleData` |
| Execution state | `!isMarketExecutableCandidate` | `.executionBlock` |
| Anomaly state | contains "unstable" in `aiRiskStance` | `.anomalyUnstable` |

### 9.2 Card Routing Summary

```
128 k universe records
  ↓  Green check (unrealizedPnL)
Strong Green (PnL ≥ 0) → eligible
Weak Green   (PnL < 0) → Blue waiting list
  ↓  Safeguard gate
  ↓  isMarketExecutableCandidate filter
  ↓  cap at 100 cards
  ↓  50 % data/score re-check (isDataStale + aiScore > 0)
  ↓  assignMarketRanks (dense rank by marketQualityTier)
→  ranked Market cards (rank > 0)
```

### 9.3 WealthAllCardsStore Sync

`materializeMarketCandidates()` calls `WealthAllCardsStore.shared.sync(...)`.
This drives the card-list UI for all card buckets (Market, Blue, Activity).

---

## 10. AI Live Pipeline

### 10.1 Scan-Progress Gate

`WealthEngineScanScheduler.hasReachedAILiveGate` must be `true` before
`WealthAILiveCoordinator.evaluateCandidates()` runs.

Gate threshold: `minimumProgressForAILive = 0.5` (phases 0-2 complete:
cacheRestore, universeScan, aiScan).

### 10.2 Promotion Filter

A card is promoted to AI Live when ALL of:
- `aiScore > 0`
- `!isDataStale`
- `isAnomalyStable`
- `earningsRisk < 70`
- `macroRisk < 75`
- `rank ≤ topTierRankThreshold` (default 3)

### 10.3 File-Backed Persistence

After evaluation:
- `WealthDownstreamCacheSanity.saveAILiveResults(eligible)` → `awc_ai_live_results.json`

On next launch restore:
- `WealthDownstreamCacheSanity.loadAILiveResults()` → restores promoted card set

---

## 11. Dashboard Snapshot   [Dashboard.swift]

`DashboardSnapshot` bundles all currently-relevant derived state:

| Field | Source property | Feature |
|---|---|---|
| `refreshTime` | `lastRefresh` | Refresh timestamp label |
| `rankedAssets` | `rankedAssets` | Card list |
| `holdings` | `holdings` | Portfolio view |
| `totalPnL` | `totalPnL` | P/L display |
| `tradingCapital` | `tradingCapital` | Capital available |
| `portfolioValue` | `portfolioValue` | Net worth display |
| `isDashboardLoading` | `isDashboardRefreshInFlight` | Loading spinner |

`beginDashboardRefresh()` → `isDashboardRefreshInFlight = true` + publish  
`endDashboardRefresh()` → `isDashboardRefreshInFlight = false` + publish

---

## 12. File-Backed Cache Persistence   [DownstreamCacheSanity.swift]

Three downstream cache files (separate from engine core cache):

| File | Contents | Freshness threshold |
|---|---|---|
| `awc_ai_live_results.json` | `[Opportunity]` — AI Live promoted cards | 30 min |
| `awc_market_snapshot.json` | `[Opportunity]` — top-N ranked cards | 30 min |
| `awc_activity_state.json` | `[String]` — admitted card symbols | 30 min |

All writes are atomic (`Data.write(.atomic)`).
Freshness is checked via file modification timestamp.

---

## 13. Universe Blueprint Source   [UniverseBlueprints.swift]

`WealthEngineStore.currentUniverseSeedSource()` returns:
1. **Persisted cache** from `WealthMarketUniverseStore` (non-blocking)
2. **Empty** — startup sequence loads asynchronously

The synchronous CSV fallback (`WealthMarketUniverseLoader.records()`) has been
intentionally removed to prevent blocking the main thread on 128 k-row loads.

---

## 14. Activity Reconciliation   [PortfolioStore+Lifecycle.swift]

`WealthPortfolioStore.rerunActivityAdmissionAfterStartup()` is called after:
1. `tradingLifecycleArmed == true`
2. `wealthEngineDidBecomeReady` notification fires

Guards:
- `tradingLifecycleArmed` must be `true`
- `WealthPortfolioLifecycleHelper` retries up to 30 times (1 s apart) if not
  yet armed when the ready notification fires

What it does:
1. Runs `WealthActivityAdmissionAudit.runAudit(on: promotedCards)` (diagnostics)
2. Calls `reconcileActivityAdmissions()` (the actual admission pass)

---

## 15. Complete Notification Inventory

| Notification | Posted by | Observed by | Effect |
|---|---|---|---|
| `wealthEngineDidBecomeReady` | `WealthReadyStateGate` | `WealthNewComponentsBootstrap` | runs post-ready audit pipeline |
| `wealthEngineDidBecomeReady` | `WealthReadyStateGate` | `WealthDownstreamCacheSanity` | validates persisted downstream state |
| `wealthEngineDidBecomeReady` | `WealthReadyStateGate` | `WealthPortfolioLifecycleHelper` | triggers Activity admission rerun |
| `wealthScanProgressDidUpdate` | `WealthEngineScanScheduler` | (any observer) | delivers `progress: Double` in userInfo |
| `wealthRefreshPhaseWillBegin` | `WealthEngineStore` | (any observer) | `userInfo["phase"]: Int` |
| `wealthRefreshPhaseDidComplete` | `WealthEngineStore` | (any observer) | `userInfo["phase"]: Int` |

---

## 16. Guard / Idempotency Summary

| Component | Guard property | Behaviour when triggered twice |
|---|---|---|
| `WealthAppSessionController.prepareLaunch()` | `hasLaunched: Bool` | no-op |
| `WealthNewComponentsBootstrap.activate()` | `isActivated: Bool` | no-op |
| `WealthEngineStartupController.beginStartupSequence()` | `startupTask == nil && !isStartupComplete` | no-op |
| `WealthEngineStore.runActivationSequence()` | `activationTask == nil` | no-op |
| `WealthDownstreamRebuildOrchestrator.triggerRebuild()` | `rebuildTask == nil` | no-op |
| `WealthSessionUnlockController.handleSessionResume()` | `resumeTask == nil` | no-op |
| `WealthEngineRuntimeCoordinator.handleBecameActive()` | `minimumResumeDebounceSecs = 2 s` | debounced |
| `WealthEngineScanScheduler.markPhaseComplete()` | `completedPhases.contains(phase)` | no-op |
| `materializeMarketCandidates()` | `isMarketMaterializationInFlight` | no-op |

---

## 17. Features That BREAK if Startup Fails

| Feature | Dependency on startup |
|---|---|
| Dashboard card list | `rankedAssets` populated by startup universe scan |
| Portfolio P/L | `holdings` restored by cache; `tradingCapital`, `portfolioValue` set during scan |
| AI Live evaluation | Requires scan progress ≥ 0.5 (`hasReachedAILiveGate`) |
| Activity queue | Requires `tradingLifecycleArmed = true` + AI Live promoted cards |
| Market ranking | Requires AI scan complete + `runMarketRanking()` |
| Order submission | Requires `tradingLifecycleArmed = true` + kill switch inactive |
| IBKR price feed | Requires timers started (`isStartupComplete`) |
| Soft/deep refresh timers | Only started after `WealthEngineStartupController` completes |
| File-backed cache sanity | Only validated after `wealthEngineDidBecomeReady` |
| Session recovery | Only runs when `isStartupComplete == true` |
| Post-ready audit pipeline | Triggered by `wealthEngineDidBecomeReady` (needs full startup + rebuild) |
