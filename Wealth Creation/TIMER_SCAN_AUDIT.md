# AWC Timer Scan Audit Report
> **AUDIT ONLY – no code changes**  
> Generated from source inspection of `Wealth Creation/` Swift files.

---

## Overview — 6 Recurring Timers

| Timer | Fires At | Property | Function Called |
|---|---|---|---|
| IBKR #1 | every 9 min | `timerHolder.ibkrTimers[0]` | `refresh(mode: .ibkr)` |
| Soft #1 | every 10 min | `softTimer` | `refresh(mode: .soft)` |
| IBKR #2 | every 19 min | `timerHolder.ibkrTimers[1]` | `refresh(mode: .ibkr)` |
| Soft #2 | every 20 min | `timerHolder.extraSoftTimers[0]` | `refresh(mode: .soft)` |
| IBKR #3 | every 29 min | `timerHolder.ibkrTimers[2]` | `refresh(mode: .ibkr)` |
| Deep | every 30 min | `heavyTimer` | `refresh(mode: .deep)` |

All timers are scheduled by `scheduleRecurringTimers()`, called from
`rescheduleTimers()`.  They are torn down by `invalidateTimers()`.
Timers are started once after the startup sequence completes.

---

## 1. 10-Minute Soft Scan (`softTimer`)

### Functions called (call chain)
```
Timer fires
  → refresh(mode: .soft)          [WealthEngineStore+Refresh.swift]
    → runSoftRefresh()
      → runUniverseScan()          → performUniverseScan()
      → runAIScan()                → performAIScan()
      → runMarketRanking()         → performMarketRanking()
                                     → materializeMarketCandidates()
```

### What data is gathered / queried

| Step | Source | Data fetched |
|---|---|---|
| `performUniverseScan()` | `WealthMarketUniverseStore` (128 k-row universe, loaded from `global_universe.csv` or on-device cache) | Every opportunity card in the universe — symbol, sector, financial metrics used for scoring |
| `performAIScan()` | In-process AI brain (reads stored brain state) | `aiScore` and confidence value recalculated for every card |
| `performMarketRanking()` → `materializeMarketCandidates()` | In-process `rankedAssets` array + `WealthCardHoldingRouter` | Green/red card routing; safeguard-gate fields read per card (see below) |

### Safeguard gate fields read per card during market ranking
- `earningsRisk` — rejected if ≥ 70  
- `macroRisk` — rejected if ≥ 75  
- `isDataStale` — rejected if stale  
- `isExecutionClean` — rejected if false  
- `isAnomalyStable` — rejected if false  
- `aiScore` — 50 % re-check: rejected if == 0  
- `marketQualityTier` — used for rank assignment  
- `isMarketExecutableCandidate` — must be true to pass  

### What gets updated in UI / state

| Property | Type | Updated by |
|---|---|---|
| `rankedAssets` | `[Opportunity]` | `performUniverseScan()` (new set of cards) |
| `rankedAssets[*].aiScore` | `Double` | `performAIScan()` (score recalculated per card) |
| `rankedAssets[*].rank` | `Int` | `assignMarketRanks()` inside `materializeMarketCandidates()` |
| `WealthAllCardsStore` (shared) | Card routing state | `materializeMarketCandidates()` calls `WealthAllCardsStore.shared.sync(...)` |
| `lastRefresh` | `Date?` | Set after universe scan completes |

---

## 2. 20-Minute Soft Scan (`soft2` in `extraSoftTimers`)

**Identical pipeline to the 10-minute scan.**  
The same function `makeSoftTimer(at:)` is called with `TimerInterval.soft2 = 20 * 60`.

```
Timer fires
  → refresh(mode: .soft)
    → runSoftRefresh()
      → runUniverseScan()   → performUniverseScan()
      → runAIScan()         → performAIScan()
      → runMarketRanking()  → performMarketRanking()
```

### What this scan does that the 10-minute scan does not

Nothing different — it is a second instance of the exact same `.soft` refresh, offset by 10 minutes, so together they produce a soft refresh every 10 minutes on the :10 and :20 marks (relative to when timers were started).

### Data gathered / state updated

Same as the 10-minute soft scan above (all three steps: universe, AI, market ranking).

---

## 3. 9, 19, 29-Minute IBKR Scans (`makeIBKRTimer`)

### Functions called (call chain)
```
Timer fires (at 9 m, 19 m, or 29 m)
  → refresh(mode: .ibkr)           [WealthEngineStore+Refresh.swift]
    → runIBKRPriceSync()
      → performIBKRSync()          [stub — implementation in WealthCore.swift]
```

`performIBKRSync()` drives `WealthIBKRBridge` over a live TCP connection to
Interactive Brokers TWS (default port 7497, host 192.168.1.21).

### What data is pulled from IBKR

The bridge sends a `REQ_MKT_DATA` message (TWS API message ID 1, version 11)
for each subscribed contract via `subscribeMarketData(contract:)`.

**Fields returned per contract (`WealthBrokerQuote`):**

| Field | Type | Description |
|---|---|---|
| `symbol` | `String` | Ticker symbol (e.g. "AAPL") |
| `bid` | `Double` | Current bid price |
| `ask` | `Double` | Current ask price |
| `last` | `Double` | Last traded price |
| `volume` | `Int` | Current day's volume |

### Contract fields sent in request

Each `WealthIBKRContract` sent to TWS contains:
- `symbol` — ticker
- `secType` — security type (e.g. "STK")
- `exchange` — e.g. "SMART"
- `currency` — e.g. "USD"
- `conId` — optional IB contract ID (0 if not known)

### How it is processed

1. TCP bytes received by `WealthIBKRBridge.startReceiving()`
2. Length-prefixed message frames parsed in `processReceiveBuffer()`
3. After handshake (`sendGreeting()` → `sendStartAPI()`), market data ticks
   arrive as TWS API messages handled in `handleApiMessage(data:)` (full
   parsing stubbed — implementation in `WealthCore.swift`)
4. Each quote emitted as a `WealthIBKRBridgeEvent.quote(WealthBrokerQuote)`
   event to all registered event handlers
5. Price fields (`bid`, `ask`, `last`, `volume`) are applied to the matching
   `rankedAssets` entry so the UI shows live prices without a full rescan

### What gets updated

- Live price fields (`bid`, `ask`, `last`, `volume`) on matched
  `Opportunity` / holding records in `rankedAssets`
- No AI rescoring, no universe reload, no market re-ranking

---

## 4. 30-Minute Deep (Heavy) Scan (`heavyTimer` / `makeDeepTimer`)

### Functions called (call chain)
```
Timer fires
  → refresh(mode: .deep)           [WealthEngineStore+Refresh.swift]
    → runDeepRefresh()
      → runUniverseScan()           → performUniverseScan()
      → runAIScan()                 → performAIScan()
      → runMarketRanking()          → performMarketRanking()
                                      → materializeMarketCandidates()
      → runResearchFeeds()          → performResearchFeeds()
```

### What is added vs. the soft scan

The deep scan adds **Step 4: `runResearchFeeds()` → `performResearchFeeds()`**.
This step appends research-feed intelligence to ranked cards (news, analyst
upgrades, institutional flow, or similar signals — implementation in
`WealthCore.swift`).

### All data gathered

| Step | Source | Data |
|---|---|---|
| `performUniverseScan()` | `WealthMarketUniverseStore` / universe CSV | Full 128 k-card universe reload and scoring |
| `performAIScan()` | AI brain | `aiScore` + confidence recalculated for every card |
| `performMarketRanking()` | In-process ranked set | Safeguard gate, top-100 filter, 50 % data re-check, rank assignment |
| `performResearchFeeds()` | External research feeds (API — implementation in WealthCore.swift) | News, analyst data, or institutional-flow signals appended to ranked cards |

### What gets updated

Same as the soft scan (`rankedAssets`, `aiScore`, rank), plus:
- Research/signal fields on ranked cards (from `performResearchFeeds()`)
- `lastHeavyRefresh` timestamp (set to `Date()` after deep refresh)
- `WealthAllCardsStore.shared` synced with updated ranked set
- File-backed caches refreshed (via `saveInBackground()` called on background)

---

## 5. Startup Activation Scan (`runStartupActivationScan` / `WealthEngineStartupController`)

There are **two startup paths** in the codebase.  The newer path
(`WealthEngineStartupController`) replaces the older
`runActivationSequence()` path.

### Newer path — `WealthEngineStartupController.beginStartupSequence()`

Called from `WealthAppSessionController.prepareLaunch()` after
`restoreCacheInBackground()` completes.

```
WealthAppSessionController.prepareLaunch()
  → WealthNewComponentsBootstrap.activate()        — registers NC observers
  → restoreCacheInBackground {
      WealthEngineStartupController.beginStartupSequence()
        → runStartupSequence()   [private, background Task]
            1. WealthEngineRuntimeRecovery.shared.runStartupIntegrityCheck()
            2. WealthEngineScanScheduler.shared.markPhaseComplete(.cacheRestore)
            3. engine.runUniverseScanWithProgress()   [phase: universeScan]
               wait 2 s
            4. engine.runAIScanWithProgress()          [phase: aiScan]
               wait 1 s
            5. engine.runMarketRankingWithProgress()   [phase: marketRanking]
               wait 1 s
            6. engine.runResearchFeedsWithProgress()   [phase: researchFeeds]
            7. engine.rescheduleTimers()               — starts all 6 recurring timers
    }
```

#### Data loaded at each startup step

| Step | Phase | Data |
|---|---|---|
| Cache restore | `cacheRestore` | `rankedAssets` ([Opportunity], JSON file), `scannedSignals` ([MarketSignal], JSON file), `holdings` ([Holding], JSON file), `lastRefresh` / `lastHeavyRefresh` (UserDefaults) |
| `runUniverseScanWithProgress()` | `universeScan` | Checks `WealthMarketUniverseStore.shared.records`. If non-empty → reuses persisted snapshot. If empty → calls `reloadForStartupSequence()` to load 128 k-row `global_universe.csv` asynchronously in the background |
| `runAIScanWithProgress()` | `aiScan` | **AI brain scan**: reads stored brain state, recalculates `aiScore` + confidence for every card |
| `runMarketRankingWithProgress()` | `marketRanking` | Routes cards through safeguard gate, builds top-100 executable green set, assigns ranks |
| `runResearchFeedsWithProgress()` | `researchFeeds` | Appends research-feed intel to ranked cards |

#### What the "AI brain scan" is

`performAIScan()` reads the engine's stored AI brain state and applies a
scoring pass across all cards loaded in `rankedAssets`.  Each card receives:
- `aiScore` — numeric confidence score (0.0–1.0 range)  
- `confidence` — secondary confidence metric  
- `aiRiskStance` — qualitative risk classification (e.g. "stable", "unstable")

#### What gets scored / ranked

1. **Universe scan** populates `rankedAssets` with raw opportunity cards  
2. **AI scan** scores every card in `rankedAssets` (aiScore, confidence)  
3. **Market ranking** filters to top-100 green, pass-safeguard cards and
   assigns integer ranks (1, 1, 2, 3, 3 … dense ranking by `marketQualityTier`)  
4. **Research feeds** augments ranked cards with signal data  
5. `WealthAllCardsStore.shared.sync(...)` publishes the final set to the UI

#### Scan-progress gate (WealthEngineScanScheduler)

`WealthEngineScanScheduler.shared` tracks 5 phases (0–4).  Progress = phases
complete / 5.  `WealthAILiveCoordinator` will not promote Market cards until
`currentProgress >= 0.5` (universe + AI scan complete = phases 1 + 2 of 5).

#### State set on completion

| Property | Value set |
|---|---|
| `activationStage` | `0` |
| `activationCycleComplete` | `true` |
| `lockedCheckpointProgress` | `Self.lockedCheckpointCount` |
| `tradingLifecycleArmed` | `true` |
| `startupSequencePhase` | `.idle` |
| `WealthEngineStartupController.isStartupComplete` | `true` |
| All 6 recurring timers | Started via `rescheduleTimers()` |

---

## Summary Table

| Timer | Interval | Function | Universe Reload | AI Rescore | Market Ranking | Research Feeds | IBKR Live Prices |
|---|---|---|---|---|---|---|---|
| IBKR #1 | 9 min | `performIBKRSync()` | ✗ | ✗ | ✗ | ✗ | ✅ bid/ask/last/vol |
| Soft #1 | 10 min | `runSoftRefresh()` | ✅ | ✅ | ✅ | ✗ | ✗ |
| IBKR #2 | 19 min | `performIBKRSync()` | ✗ | ✗ | ✗ | ✗ | ✅ bid/ask/last/vol |
| Soft #2 | 20 min | `runSoftRefresh()` | ✅ | ✅ | ✅ | ✗ | ✗ |
| IBKR #3 | 29 min | `performIBKRSync()` | ✗ | ✗ | ✗ | ✗ | ✅ bid/ask/last/vol |
| Deep | 30 min | `runDeepRefresh()` | ✅ | ✅ | ✅ | ✅ | ✗ |
| Startup | once | `runStartupSequence()` | ✅ | ✅ | ✅ | ✅ | ✗ (armed after) |

---

## Data Sources Reference

| Source | What it contains |
|---|---|
| `WealthMarketUniverseStore` | Persisted on-device cache of all opportunity records loaded from `global_universe.csv` (~128 k rows) |
| AI brain (in-process) | Stored model state used to compute `aiScore` and `confidence` per card |
| IBKR TWS (TCP 192.168.1.21:7497) | Live market quotes: `bid`, `ask`, `last`, `volume` per subscribed symbol |
| Research feeds (external API) | News / analyst / flow data appended to ranked cards at deep-scan time |
| File-backed cache (Caches dir) | `awc_engine_ranked_assets.json`, `awc_engine_scanned_signals.json`, `awc_engine_holdings.json`, `awc_ai_live_results.json`, `awc_market_snapshot.json`, `awc_activity_state.json` |
| UserDefaults | `awc_engine_last_refresh` (Date), `awc_engine_last_heavy_refresh` (Date) |
