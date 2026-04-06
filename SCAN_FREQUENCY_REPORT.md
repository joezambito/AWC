# Scan Frequency Root-Cause Report

## Observed Behaviour

Universe scan, AI scan, and market scan all trigger together approximately every
**5 minutes**, visible in the Xcode console log.  The expected cadence (per the
timer design) is every 10 minutes for soft scans (universe + AI + market) and
every 30 minutes for a full deep scan.

---

## Root Cause

### Primary cause — legacy timers not invalidated

`WealthEngineStore` declares two stored timer properties that are created and
scheduled by **WealthCore.swift** (the original app source, not committed to
the repository):

| Property | Declared in | Managed by | Interval |
|---|---|---|---|
| `scheduledCheckpointTimer` | `WealthEngineStore.swift` line 147 | WealthCore.swift | ~5 min (legacy) |
| `preScanBurstTimer` | `WealthEngineStore.swift` line 151 | WealthCore.swift | ~5 min (legacy) |

When WealthCore.swift starts either of these timers it calls the existing
scan pipeline (universe → AI → market) on every tick.

`invalidateTimers()` in `WealthEngineStore+Timers.swift` was only tearing down
the **six new timers** introduced in the refactored timer architecture.  It did
**not** touch `scheduledCheckpointTimer` or `preScanBurstTimer`, so those
WealthCore.swift-managed timers kept firing at their ~5-minute interval
independently of the new schedule, causing the observed every-5-minute full
scan cycle.

---

## All Responsible Files and Their Roles

### 1 · `Wealth Creation/WealthEngineStore+Timers.swift`

**The timer hub.** Defines and schedules the six post-startup recurring timers.
`rescheduleTimers()` calls `invalidateTimers()` then `scheduleRecurringTimers()`.
**Before the fix**, `invalidateTimers()` did not include `scheduledCheckpointTimer`
or `preScanBurstTimer`.

| Timer constant | Interval | Fires | Scan type |
|---|---|---|---|
| `TimerInterval.ibkr1` | 9 min | `refresh(mode: .ibkr)` | IBKR price sync only |
| `TimerInterval.soft1` | 10 min | `refresh(mode: .soft)` | universe + AI + market |
| `TimerInterval.ibkr2` | 19 min | `refresh(mode: .ibkr)` | IBKR price sync only |
| `TimerInterval.soft2` | 20 min | `refresh(mode: .soft)` | universe + AI + market |
| `TimerInterval.ibkr3` | 29 min | `refresh(mode: .ibkr)` | IBKR price sync only |
| `TimerInterval.deep` | 30 min | `refresh(mode: .deep)` | universe + AI + market + research |



### 2 · `Wealth Creation/WealthEngineStore.swift`

**Stores all timer references** as instance properties:

- `softTimer` — primary soft-refresh timer (10 min slot)
- `heavyTimer` — primary deep-refresh timer (30 min slot)
- `scheduledCheckpointTimer` — **legacy** timer created by WealthCore.swift
- `preScanBurstTimer` — **legacy** burst timer created by WealthCore.swift

### 3 · `Wealth Creation/WealthEngineStartupController.swift`

**Calls `rescheduleTimers()` once** after the startup sequence
(universe → AI → market → research) completes.  This is the only place timers
are armed post-launch.

### 4 · `Wealth Creation/WealthEngineStore+Refresh.swift`

**Defines the three scan pipelines** invoked by every timer:

```
.ibkr  → runIBKRPriceSync()    (price sync only)
.soft  → runUniverseScan()
         runAIScan()
         runMarketRanking()
.deep  → runUniverseScan()
         runAIScan()
         runMarketRanking()
         runResearchFeeds()
```

Any timer that calls `refresh(mode: .soft)` or `refresh(mode: .deep)` triggers
a full universe download.

### 5 · `Wealth Creation/WealthStaleCacheDetector.swift`

**5-minute post-unlock stale threshold** (`postUnlockStaleThreshold`):

```swift
let postUnlockStaleThreshold: TimeInterval = 5 * 60
```

On every `applicationDidBecomeActive` event (app foreground / device unlock),
`checkAndRebuildIfNeeded()` fires an AI + market rebuild (not universe) if
`lastRefresh` is older than 5 minutes.  This is an event-driven trigger —
not a repeating timer — and it **does not** include the universe scan.

### 6 · `Wealth Creation/WealthEngineRuntimeCoordinator.swift`

**Receives every `applicationDidBecomeActive`** event and forwards
it to `WealthSessionUnlockController.handleSessionResume()` when startup is
complete.  That in turn calls `WealthStaleCacheDetector.checkAndRebuildIfNeeded()`.

### 7 · `Wealth Creation/WealthBackgroundRefreshCoordinator.swift`

**OS-triggered background refresh** (`minimumRefreshInterval = 15 min`).  Minimum interval: 15 minutes.
Not responsible for the 5-minute observation.

---

## Precise Call Chain That Causes Every-5-Minute Universe Scan

```
WealthCore.swift
  scheduledCheckpointTimer / preScanBurstTimer  (fires every ~5 min)
    └─ [calls existing scan entry-point – WealthCore.swift internal]
         └─ WealthEngineStore.performUniverseScan()   ← universe download
         └─ WealthEngineStore.performAIScan()
         └─ WealthEngineStore.performMarketRanking()
```

Because `invalidateTimers()` never cleared these two timer properties, they
survived every call to `rescheduleTimers()` and continued to fire.

---

## Fix Applied

**File:** `Wealth Creation/WealthEngineStore+Timers.swift`
**Function:** `invalidateTimers()`

Added invalidation of the two legacy timer properties immediately after the
existing soft/deep timer teardown:

```swift
// Invalidate legacy timers that WealthCore.swift may have scheduled.
// These are NOT managed by the holder above and must be cleared here
// to prevent them from firing the full scan cycle independently of
// the six-timer schedule defined in this file.
scheduledCheckpointTimer?.invalidate()
scheduledCheckpointTimer = nil
preScanBurstTimer?.invalidate()
preScanBurstTimer = nil
```

`invalidateTimers()` is called from two places:
1. `rescheduleTimers()` — at startup completion (via `WealthEngineStartupController`)
2. `resetToFactoryDefaults()` — on factory reset / sign-out

After this fix, the next call to `rescheduleTimers()` kills both legacy timers
before the six-timer schedule starts, eliminating the spurious 5-minute scan cycle.

---

## Expected Scan Cadence After Fix

Starting from startup completion (T = 0):

| Time from T | Event | Scans |
|---|---|---|
| Startup | `WealthEngineStartupController` one-time sequence | universe → AI → market → research |
| T + 9 min | IBKR timer 1 | IBKR price sync only |
| T + 10 min | Soft timer 1 | universe + AI + market |
| T + 19 min | IBKR timer 2 | IBKR price sync only |
| T + 20 min | Soft timer 2 | universe + AI + market |
| T + 29 min | IBKR timer 3 | IBKR price sync only |
| T + 30 min | Deep timer | universe + AI + market + research |

Cycle repeats every 30 minutes thereafter.  The universe scan now runs at
T+10, T+20, T+30, T+40, T+50, T+60 ... — every **10 minutes** — not every
5 minutes.

---

## Summary Table

| File | Role | Contributes to 5-min scan? |
|---|---|---|
| `WealthEngineStore+Timers.swift` | Timer hub; `invalidateTimers()` bug | **Yes — bug fixed here** |
| `WealthEngineStore.swift` | Stores `scheduledCheckpointTimer` / `preScanBurstTimer` | Yes — legacy properties |
| WealthCore.swift (not in git) | Schedules legacy timers at ~5 min | Yes — original source |
| `WealthEngineStore+Refresh.swift` | scan pipelines (.soft / .deep include universe) | Indirectly |
| `WealthEngineStartupController.swift` | Arms timers post-startup | No (one-time) |
| `WealthStaleCacheDetector.swift` | 5-min post-unlock AI+market rebuild | No (event-driven, no universe) |
| `WealthEngineRuntimeCoordinator.swift` | Foreground-activation handler | No (no universe) |
| `WealthBackgroundRefreshCoordinator.swift` | OS background refresh (15 min min) | No |
