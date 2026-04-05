# AWC – Architecture

This document describes the component structure, data flow, and key design
decisions in the AWC engine.

---

## Overview

AWC is a Mac Catalyst app structured around a single observable state
container (`WealthEngineStore`) that drives all SwiftUI views.  All engine
logic runs in Swift extensions and helper singletons rather than in one
monolithic class, keeping each file to approximately 200–300 lines.

```
ContentView
    │
    ├─ WealthEngineStore.shared          (@MainActor ObservableObject)
    │       │
    │       ├─ WealthEngineStore+Bootstrap        app launch / foreground hooks
    │       ├─ WealthEngineStore+Activation       one-time startup sequence
    │       ├─ WealthEngineStore+Timers           6 recurring timers
    │       ├─ WealthEngineStore+Refresh          IBKR / soft / deep refresh
    │       ├─ WealthEngineStore+Materialization  market ranking + safeguard gate
    │       ├─ WealthEngineStore+Cache            synchronous persistence
    │       ├─ WealthEngineStore+BackgroundCache  off-thread persistence
    │       ├─ WealthEngineStore+Dashboard        snapshot helpers
    │       └─ WealthEngineStore+Recovery         error recovery / factory reset
    │
    ├─ PersistenceManager               atomic bundle write (Issue 6)
    ├─ MarketDataFetcher                REST quote fetching (Issue 7)
    ├─ AWCSecretConfig                  .env loader (Issue 8)
    │
    ├─ WealthIBKRBridge                 TCP connection to TWS
    ├─ WealthBrainStore                 AI scoring engine
    ├─ WealthAILiveCoordinator          card promotion to Activity
    ├─ WealthActivityAdmissionAudit     admission gate audit
    ├─ WealthMarketExecutionAudit       execution-readiness audit
    ├─ WealthOrderRestrictionRules      order-restriction audit
    ├─ WealthDownstreamCacheSanity      file-backed downstream caches
    ├─ WealthEngineScanScheduler        scan-phase progress tracking
    ├─ WealthEngineStartupController    staggered startup sequence
    ├─ WealthEngineRuntimeCoordinator   foreground-resume handling
    └─ WealthEngineRuntimeRecovery      stuck-state detection + repair
```

---

## Threading model

| Thread / Actor | What runs here |
|---|---|
| `@MainActor` (main thread) | All `@Published` assignments, all engine singletons, SwiftUI |
| `Task.detached(.userInitiated)` | Universe scan, AI scan, market ranking, research feeds |
| `Task.detached(.utility)` | Background cache save (`saveInBackground`) |

The class-level `@MainActor` annotation on `WealthEngineStore` guarantees
that every extension method runs on the main thread, eliminating the need
for per-site `DispatchQueue.main.async` wrappers.

---

## Startup sequence

```
App launch
    │
    ▼
WealthAppSessionController.prepareLaunch()
    │
    ├─ WealthNewComponentsBootstrap.activate()      registers NC observers
    │
    └─ WealthEngineStore.restoreCacheInBackground() ─► background task
            │                                         • loads atomic bundle
            ▼                                         • assigns @Published
       WealthEngineStartupController.beginStartupSequence()
            │
            ├─ WealthEngineRuntimeRecovery.runStartupIntegrityCheck()
            ├─ Universe scan  (background Task)
            │       wait 2 s
            ├─ AI scan        (background Task)
            │       wait 1 s
            ├─ Market ranking (background Task)
            │       wait 1 s
            └─ Research feeds (background Task)
                    │
                    └─ WealthEngineStore.rescheduleTimers()
                            schedules 6 recurring timers
```

---

## Persistence (Issue 6)

Before Issue 6: rankedAssets, scannedSignals, and holdings were written to
three separate files in sequence.  If the process was interrupted between
writes, the on-disk state could contain a mix of data from different scan
cycles.

After Issue 6 (`PersistenceManager`): all three arrays and both timestamps
are encoded into a single `EngineStateBundle` struct and written with one
`Data.write(to:options:.atomic)` call.  The atomic write uses a
temp-file-then-rename(2) strategy, so either the full bundle is committed
or the previous bundle is left unchanged.

A migration fallback reads the legacy individual files when the bundle file
does not yet exist, ensuring existing installs are not data-wiped on the
first upgrade.

---

## Async callback safety (Issue 7)

`MarketDataFetcher.fetchQuote(for:)` creates a `Task { [self] in … }` that
captures `self` strongly.  This guarantees the fetcher object remains alive
for the full duration of the network round-trip even if the owner drops its
reference.  In-flight tasks are cancelled before re-issuing the same symbol
so stale callbacks never overwrite fresher results.

---

## Secret management (Issue 8)

`AWCSecretConfig` reads a plain-text `awc.env` file from the app's
Documents folder at launch.  No credentials, API keys, or connection
parameters appear in source files.  The `.gitignore` entry for `awc.env`
prevents accidental commits.

---

## Timer schedule

| Interval | Type | Stage | Work |
|---|---|---|---|
|  9 min | IBKR | 0 | Live price sync only |
| 10 min | Soft | 1 | Universe + AI + market ranking |
| 19 min | IBKR | 2 | Live price sync only |
| 20 min | Soft | 3 | Universe + AI + market ranking |
| 29 min | IBKR | 4 | Live price sync only |
| 30 min | Deep | 5 | Everything (+ research feeds) |

---

## Card lifecycle

```
Scored Opportunities (rankedAssets)
        │
        ▼
WealthCardHoldingRouter.routeFromGreenCheckpoint()
        │
        ├─ Strong Green (P/L ≥ 0) ──────────────────────────────┐
        ├─ Weak Green   (P/L < 0) → BLUE (waiting, not ranked)  │
        └─ Fail → RED / GREY                                     │
                                                                  ▼
                                              Safeguard gate (per card):
                                              earningsRisk < 70 AND
                                              macroRisk < 75 AND
                                              data not stale AND
                                              execution clean AND
                                              anomaly stable
                                                                  │
                                                                  ▼
                                              Top 100 market candidates
                                              + 50% data/score re-check
                                              + dense rank assignment
                                                                  │
                                                                  ▼
                                              WealthAILiveCoordinator
                                              (scan-progress gated ≥ 50%)
                                                                  │
                                                                  ▼
                                              Activity admission audit
                                                                  │
                                                                  ▼
                                              Activity queue
```
