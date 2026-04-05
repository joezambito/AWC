# AWC Swift Codebase — Cross-Analysis: Critical Bugs & Critical Errors
**Synthesised from:** PR #35 (Full static audit — 20 critical issues) and PR #36 (Full Swift audit — diagnosis report)
**Code verified against:** all 33 committed Swift source files in `Wealth Creation/`
**Date:** 2026-04-05 | **No code changes made. Report only.**

---

## The Story in Plain English

Both audits were run independently, on the same codebase, at nearly the same point in time.
They agree on every major finding.
That agreement is the headline: this isn't one auditor being overly harsh — the same structural failures show up from two different angles every time.

The codebase is a set of extension-only Swift files layered over a core application (`WealthCore.swift`) that is **not committed to git**. Every single type — `WealthEngineStore`, `Opportunity`, `WealthPortfolioStore`, `WealthAllCardsStore`, `MarketSignal`, `Holding` — is defined in that absent file. The 33 committed files cannot be compiled, run, or verified in isolation. This is the invisible ceiling over every finding below: the true severity of compile errors and shadowed implementations can only be known at build time with the full project.

Within that constraint, both audits identify **five interlocking failure clusters** that explain why the app's core outputs — the Activity feed, market rankings, and AI-scored cards — can produce empty or incorrect results even when the app appears to be running normally.

---

## Five Failure Clusters

### Cluster 1 — The Pipeline Dead Zone
*Both reports flag this. Independently confirmed in source.*

**The rank-zero bug (most critical single line in the codebase):**
In `WealthEngineStore+Materialization.swift`, `assignMarketRanks(to: recheckPassed)` computes a correctly-ranked array and stores it in `let ranked`. On the very next call, `WealthAllCardsStore.shared.sync(opportunities: rankedAssets, ...)` passes `rankedAssets` — the original, unranked array — rather than `ranked`. The ranked result is computed and immediately discarded. Every card has `rank == 0` for the entire session.

Downstream, `WealthAILiveCoordinator` filters candidates with `{ $0.rank > 0 }`. Because nothing has rank > 0, the filter returns an empty set. Activity is permanently empty every cycle, not because no opportunities exist but because the ranking result is never written back.

**Brain bias never applied (second bullet in the same cluster):**
`WealthBrainStore.ingest()` calls `learn()`, logs a diagnostic message, and returns. It never calls `bias()`. `bias()` has zero call sites in any committed file. The brain accumulates observations every scan cycle and writes a log entry every time — giving a convincing appearance of activity — but no learned signal is ever applied to card scores. The brain is a spectator.

These two bugs operate independently but produce the same visible outcome: Activity shows nothing, scores don't improve over time.

---

### Cluster 2 — The Split-Brain Startup
*Both reports flag this. Confirmed across Activation.swift, Bootstrap.swift, StartupController.swift.*

The codebase contains two startup pipelines.

**Path A** (`WealthEngineStore+Activation.swift → runActivationSequence()`): The older sequence. Sets `tradingLifecycleArmed`, `activationCycleComplete`, `startupSequencePhase`, and `activationStage`. Tears down a set of named timers (`scheduledCheckpointTimer`, `softTimer`, `heavyTimer`, `preScanBurstTimer`) that may or may not exist under the current timer architecture. Calls methods (`endDashboardRefreshFreeze()`, `runStartupActivationScan()`, `runStartupMarketWarmup()`, and properties like `phoneStartupScanDelayNanoseconds`, `lockedCheckpointProgress`, `lockedCheckpointCount`, `downstreamRecoveryPending`) that are defined only in non-committed `WealthCore.swift`.

**Path B** (`WealthEngineStore+Bootstrap.swift → WealthAppSessionController → WealthEngineStartupController`): The current path, now the only one called. Never sets `tradingLifecycleArmed`, `activationCycleComplete`, or `startupSequencePhase`. These flags stay at their default values for the entire session.

`WealthPortfolioLifecycleHelper` reads `tradingLifecycleArmed` from `WealthPortfolioStore.shared`. It retries once per second for up to 30 seconds waiting for the flag to become `true`. Since Path B never sets it, the helper reaches `maxRetryAttempts`, logs "gave up," and stops. Activity admission never runs. This path-dependency silently blocks admission even when ranking and scoring are working.

**Compounding detail:** `scheduleArmedRetry` in `WealthPortfolioLifecycleHelper` creates a new `retryTask` on each recursive call without cancelling the previous one first. After 30 iterations, 30 concurrent tasks exist, all waiting to call `triggerAdmissionRerun()` the moment the flag ever becomes `true`. When it does, 30 simultaneous admission reruns fire.

---

### Cluster 3 — Placeholder Risk Values Poisoning the Safeguard Gate
*Both reports flag this. Confirmed with explicit `⚠️ PLACEHOLDER` warnings in source.*

The safeguard gate in the materialization pipeline decides which cards are allowed to proceed to market ranking. Two of its five checks read from `Opportunity+CardStateMachine.swift`:

- `earningsRisk` = `Int(risk * 100)` — a generic risk float rescaled to 0–100.
- `macroRisk` = `Int((1 - probability) * 100)` — inverted probability, not macro risk.

Both properties carry explicit production warnings in the source:
> "⚠️ PLACEHOLDER — WILL produce incorrect safeguard decisions in production until replaced."

The safeguard gate rejects cards when `earningsRisk >= 70` or `macroRisk >= 75`. With placeholder values, cards are admitted or rejected based on rescaled generic-risk and inverted-probability figures, not on actual earnings calendar data or macro event exposure. High-probability opportunities with low actual risk may be wrongly rejected; genuinely risky cards may pass.

Every downstream ranking, every Activity card, every AI Live evaluation is built on a gate whose admission logic is acknowledged to be wrong.

---

### Cluster 4 — The Self-Triggering Rebuild Loop
*Both reports flag this. Confirmed in WealthStaleCacheDetector.swift.*

`WealthStaleCacheDetector.checkAndRebuildIfNeeded()` evaluates four staleness conditions. When any condition is true it calls `triggerRebuild(reason: reasons)` — expected behaviour. When **all** conditions are false (data is completely fresh) the `else` branch calls `triggerRebuild(reason: "session-resume")` unconditionally.

Every foreground event — every screen unlock, every app-switch return, every scene activation — calls `checkAndRebuildIfNeeded()` via `WealthSessionUnlockController`. Even with perfectly fresh data, a full downstream rebuild (AI + Market pipeline) triggers every single time.

In practice, during a normal session, this means the AI + Market pipeline runs in a continuous loop driven entirely by foreground events, independent of whether data has changed. The rebuild cycle initiated by this path re-enters the same coordinator, which can trigger the same check again on completion — creating a notification-driven rebuild loop.

---

### Cluster 5 — Recovery Leaves the Engine Idle
*Both reports flag this. Confirmed in WealthEngineRuntimeRecovery.swift and WealthEngineStore+Recovery.swift.*

`WealthEngineRuntimeRecovery.performFullRecovery()` does the right cleanup: cancels rebuilds, resets the ready-state gate, and calls `recoverFromFailedRefresh()`. `recoverFromFailedRefresh()` clears in-flight flags, releases task handles, and restores the last persisted snapshot.

Neither method re-queues the startup sequence or reschedules timers. After recovery, the engine has clean state and a populated cache but runs nothing. No scan, no timer, no pipeline. It sits idle until the user force-quits and relaunches the app.

Also in `WealthEngineStore+Cache.swift`: the doc comment on `restoreCache()` states "Large array decoding is NOT performed here — call `restoreCacheInBackground`." The implementation then directly calls `restoreRankedAssetsFromFile()`, `restoreScannedSignalsFromFile()`, and `restoreHoldingsFromFile()` — all synchronous file decoders. Called from the `@MainActor` recovery path, this decodes potentially 128k ranked assets on the main thread, reproducing the exact freeze the background-cache system was built to prevent.

---

## Supporting Issues (Confirmed by Both Reports)

| Issue | File | Status |
|---|---|---|
| `WealthEngineScanScheduler.completedPhases` never cleared between timer cycles | `WealthEngineScanScheduler.swift` | `reset()` method exists but no caller invokes it between timer cycles. AI Live gate reads stale 100% progress after startup. |
| IBKR `conn.start(queue: .main)` + receive loop on main thread | `WealthIBKRBridge.swift:96` | All NWConnection callbacks fire on main queue; tick data saturates UI thread during market hours. |
| `subscribeMarketData()` never writes to `subscriptions` dict | `WealthIBKRBridge+Send.swift` | No cancel-on-disconnect, no reconnect re-subscription. |
| `resetToFactoryDefaults()` defined in both committed files and `WealthCore.swift` | `WealthEngineStore+Recovery.swift` | Source NOTE says "remove the original stub" but WealthCore.swift is not committed; duplicate status is unverifiable without it. |
| `WealthEngineStore+Refresh.swift` stubs: `performResearchFeeds()`, `performIBKRSync()` empty | `WealthEngineStore+Refresh.swift` | Research feeds and IBKR price sync are no-ops in all committed files. |
| `Task.detached` wrapping `@MainActor` methods | `WealthEngineStore+Refresh.swift` | `Task.detached` schedules work on a background executor, but `@MainActor` methods always hop back to the main actor. Background execution comment is misleading; actual UI-blocking risk depends on WealthCore.swift implementations. |

---

## Unique Findings by Report

### Only in PR #35 (Static Audit)
- **`nonisolated(unsafe)` on `timerHolder`** (`WealthEngineStore+Timers.swift:31`): Suppresses actor isolation checks for timer arrays. Concurrency violations on timer access will not be caught at compile time.
- **`// MARK: - Public API` inline on property declaration** (`WealthStaleCacheDetector.swift:46`): Section separator is treated as an inline comment; invisible in Xcode jump bar.
- **Safeguard gate rejects using wrong fields `earningsRisk`/`macroRisk`** diagnosed as breaking the _gate logic_ specifically, not just card metadata.

### Only in PR #36 (Diagnosis Report)
- **`resetToFactoryDefaults()` duplicate = compile error**: If `WealthCore.swift` retains its original stub, the committed override in `Recovery.swift` is a build-time duplicate definition error.
- **`WealthEngineStore+UniverseBlueprints.swift`** returns an empty universe on cold start / cache clear: callers live in non-committed WealthCore.swift and cannot be fully audited, but blueprint fallback produces an empty starting state.
- **`WealthEngineRefresh+LifecyclePublishing.swift`** (medium severity): Lifecycle publishing pipeline not auditable without WealthCore.swift symbol resolution.

---

## Overlapping Issues (Both Reports Independently Confirm)

1. `assignMarketRanks()` result discarded → rank == 0 → Activity always empty
2. `WealthBrainStore.bias()` never called → brain learns but never influences scores
3. Dual startup paths (`runActivationSequence` vs `WealthEngineStartupController`)
4. `tradingLifecycleArmed` / `activationCycleComplete` never set by active startup path
5. `earningsRisk` and `macroRisk` are confirmed placeholders feeding the safeguard gate
6. `performResearchFeeds()` and `performIBKRSync()` are empty stubs
7. `WealthStaleCacheDetector` unconditional rebuild on every foreground event
8. `restoreCache()` synchronous large-array decode on main thread
9. `performFullRecovery()` does not re-queue startup after engine reset
10. IBKR `conn.start(queue: .main)` delivering all callbacks on main queue

---

## Key Technical Risks — Summary

**Risk 1 — Zero visible output (Activity permanently empty)**
The rank-zero bug and the unconditional empty-filter on `rank > 0` mean the app's primary output is empty by design-time defect, not runtime data failure. No scan improvement will fix this until the ranked array is written back before sync.

**Risk 2 — Wrong cards in the pipeline**
Placeholder safeguard values (`earningsRisk`, `macroRisk`) mean admission decisions are incorrect for every card processed. The cards that make it through are not necessarily the best — they are the ones with the right combination of generic risk score and probability, not the right earnings and macro risk profile.

**Risk 3 — Continuous background rebuild storm**
The unconditional `triggerRebuild(reason: "session-resume")` in `WealthStaleCacheDetector` means the full AI + Market pipeline runs on every foreground event indefinitely, regardless of data freshness. Combined with the task-leak in `WealthPortfolioLifecycleHelper`, a session with multiple background/foreground cycles accumulates a growing number of overlapping rebuild and admission tasks.

**Risk 4 — Non-recoverable failure states**
Recovery clears state correctly but never re-arms the engine. After any recovery event, the engine becomes permanently idle until next app launch. In production, any transient network failure or decode error that triggers recovery leaves the user with a clean but permanently inactive app.

**Risk 5 — Unauditable build surface**
All 33 committed files are extensions on types defined in an absent file. Duplicate definitions, unresolved symbols, and shadowed implementations can produce silent wrong-behavior or compile errors that are invisible until the full project is built. Both audits call this out as the structural constraint that makes every other finding provisional.

---

## Narrative: What Actually Happens at Runtime

1. App launches. `bootstrap()` routes to `WealthAppSessionController.prepareLaunch()` (Path B). `runActivationSequence()` (Path A) is never called.
2. Cache is restored synchronously on the main thread, decoding up to 128k ranked assets and blocking the UI.
3. `WealthEngineStartupController.beginStartupSequence()` runs the 4-step scan pipeline. `performUniverseScan()` and `performResearchFeeds()` / `performIBKRSync()` are stubs — their implementations live in non-committed WealthCore.swift. Whether real data flows depends entirely on that file.
4. `performAIScan()` calls `WealthBrainStore.ingest()` → `learn()` (stub) → logs "Brain Ingest". Brain does nothing observable.
5. `performMarketRanking()` calls `materializeMarketCandidates()`. Safeguard gate runs with placeholder risk values. `assignMarketRanks()` produces a correctly-ranked array. The ranked array is discarded; `WealthAllCardsStore.sync()` receives the original unranked array. All cards: `rank == 0`.
6. `WealthAILiveCoordinator` evaluates candidates: `{ $0.rank > 0 }` → empty set. Activity: empty.
7. `tradingLifecycleArmed` is never set by Path B. `WealthPortfolioLifecycleHelper` retries 30 times, logs "gave up." Admission never runs.
8. User puts app in background and returns. `WealthStaleCacheDetector.checkAndRebuildIfNeeded()` fires. Data is fresh, so the `else` branch runs: `triggerRebuild(reason: "session-resume")`. Full AI + Market pipeline fires again. Cards come back with rank == 0. Activity: still empty.
9. A network error triggers recovery. `performFullRecovery()` resets all state. Timers are not restarted. Engine sits idle. No further scans run.
10. IBKR connects. All tick callbacks fire on the main queue. UI responsiveness degrades during market hours.

The app produces no Activity output, no ranked cards, and no AI-influenced scores in its current committed state. The symptoms are reproducible and consistent because they stem from structural bugs (wrong variable passed to sync, zero call sites for `bias()`, wrong flag set by the active startup path), not from intermittent timing or data quality issues.

---

*Report only. No code has been added, changed, or deleted.*
