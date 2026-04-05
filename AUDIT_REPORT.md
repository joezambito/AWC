# AWC Swift Codebase — Cross-Analyzed Audit Report

> **Scope:** All 33 Swift source files in `Wealth Creation/`  
> **Purpose:** Plain-language diagnosis only. No code changes. No suggestions.  
> **Date:** April 2026

---

## Executive Summary

The AWC engine is architecturally ambitious: a multi-stage pipeline that downloads a 128,000-row market universe, scores every card with AI, gates them through a safeguard layer, ranks the survivors, and finally routes qualified candidates through an "AI Live" evaluation into an Activity queue. That vision is well-structured on paper.

In practice, the codebase is in a **transitional state**. The new extension layer (all 33 committed files) was built on top of a core engine (`WealthCore.swift`) that lives outside version control. This creates the defining risk of the entire project: **the extensions call into a hidden foundation that cannot be audited, tested, or verified in this repository.** Every critical scan step, every AI score calculation, and every persistence save that matters ultimately falls into that invisible file.

The extensions themselves are well-organized and clearly commented — but they contain a cascade of stubs, placeholder calculations, and silent failure paths that collectively mean the pipeline as committed **does not execute any real work end-to-end.**

---

## Key Themes Around Code Health

### Theme 1: Pervasive Stub Functions — The Engine Fires Blanks

The most systemic issue is that every major scan entry-point is an empty method body. The startup sequence runs four phases (universe, AI, market ranking, research feeds), schedules timers, calls callbacks — and all of it lands in methods that do nothing:

- `performUniverseScan()` — empty body
- `performResearchFeeds()` — empty body
- `performIBKRSync()` — empty body
- `WealthBrainStore.learn()` — empty stub
- `WealthBrainStore.bias()` — empty stub
- `WealthIBKRBridge.handleApiMessage(data:)` — empty body

The comment on each says "Implemented in WealthCore.swift." The engine starts, the timers tick, the orchestration flows — and then nothing meaningful happens because every actual implementation is in a file that is not in the repository.

### Theme 2: Placeholder Risk Math Driving Real Gate Decisions

Two properties — `earningsRisk` and `macroRisk` — are explicitly marked in the source code as **semantically wrong placeholders** that will produce incorrect safeguard decisions in production. Despite being labeled as temporary approximations, they are actively used in the safeguard gate that controls which market cards survive to AI Live and Activity. The gate is wired to real thresholds (70 and 75) against values derived from unrelated fields (`risk` float and inverted `probability`). This means the safeguard gate is currently filtering on the wrong data.

### Theme 3: Silent Error Swallowing Throughout the Persistence Layer

Every file write, file read, and JSON decode in the codebase uses `try?` with no error handling. There is no path where a disk write failure, a decode error, or a cache corruption event produces any user-visible feedback or logs a diagnostic. When persistence silently fails, the engine behaves as if it succeeded — the next launch sees an empty or stale cache and re-runs a full download cycle with no explanation.

### Theme 4: The Ready-State Gate Only Fires Once

`WealthReadyStateGate.markDownstreamRebuildComplete()` is designed to post the `wealthEngineDidBecomeReady` notification that triggers audits, cache saves, and AI Live evaluation after every rebuild. The implementation guards this notification behind `if !wasReady && isFullyReady` — meaning it fires **only on the first transition to ready, never again.** After the initial launch, every subsequent session-resume rebuild completes silently. No audits run. No AI Live evaluation re-runs. No file-backed caches are updated. The entire post-ready pipeline is a one-shot that never repeats.

### Theme 5: Fragile Lifecycle Coupling via One-Second Polling

`WealthPortfolioLifecycleHelper` waits for `tradingLifecycleArmed` to become `true` by polling once per second for up to 30 seconds. If the property never transitions — which is possible given that the property is set inside `WealthCore.swift`'s activation logic that cannot be verified — the helper silently gives up and the Activity queue is never rerun after startup. This is an unconditional silent failure with no retry mechanism and no escalation.

### Theme 6: The IBKR Bridge is Wired but Deaf

The IBKR TCP connection, handshake, and message framing logic are fully implemented and correctly structured. However, `handleApiMessage(data:)` — the method that receives every incoming market data tick, account update, and order fill from TWS — has an empty body. The bridge can send messages, parse the handshake, and emit connection events, but it cannot process any response from the broker. Live prices, portfolio updates, and order acknowledgments are received and immediately discarded.

### Theme 7: Split-Brain Architecture (Extensions vs. WealthCore.swift)

The 33 committed files are entirely Swift extensions on types whose base definitions live in `WealthCore.swift` outside version control. The extensions reference stored properties (`rankedAssets`, `activationTask`, `tradingLifecycleArmed`, `killSwitch`, etc.) that are defined in the hidden file. This means:

- The committed code cannot be compiled independently.
- Bugs in the base definitions are invisible from this repository.
- Any change to `WealthCore.swift` can silently break the extension logic without a visible diff.

---

## Critical Recurring Bugs — Explicit Locations

### BUG-1: Empty Universe Scan (Highest Priority)
**File:** `Wealth Creation/WealthEngineStore+Refresh.swift`  
**Function:** `performUniverseScan()` — lines 102–107  
**What happens:** The startup controller calls this as Step 1 of the four-phase launch sequence. The method has no implementation. The entire downstream pipeline (AI scoring, market ranking, Activity admission) builds on an empty dataset.

---

### BUG-2: Placeholder Earnings Risk Producing Wrong Safeguard Decisions
**File:** `Wealth Creation/Opportunity+CardStateMachine.swift`  
**Property:** `earningsRisk` — lines 63–74  
**What happens:** The safeguard gate in `materializeMarketCandidates()` rejects any card with `earningsRisk >= 70`. This value is computed as `Int((risk * 100).rounded())` where `risk` is a generic float that is not earnings-specific. Cards that have low generic risk but high earnings-event exposure pass incorrectly. Cards with high generic risk but safe earnings positions are incorrectly blocked.

---

### BUG-3: Placeholder Macro Risk Producing Wrong Safeguard Decisions
**File:** `Wealth Creation/Opportunity+CardStateMachine.swift`  
**Property:** `macroRisk` — lines 75–88  
**What happens:** The safeguard gate rejects cards with `macroRisk >= 75`. This value is computed as `Int(((1.0 - probability) * 100).rounded())` — the inverse of the AI probability score, which is not macro-event risk. A high-confidence AI recommendation (probability near 1.0) would show near-zero macro risk regardless of actual market conditions.

---

### BUG-4: Research Feeds Phase Is an Empty Stub
**File:** `Wealth Creation/WealthEngineStore+Refresh.swift`  
**Function:** `performResearchFeeds()` — lines 128–131  
**What happens:** Every 30-minute deep refresh and every startup sequence ends with a research feeds pass. The method is empty. No research intel is ever appended to ranked cards. The `WealthResearchFeedEngine` and `WealthResearchIntelStore` types exist but are not connected.

---

### BUG-5: IBKR Price Sync Does Nothing
**File:** `Wealth Creation/WealthEngineStore+Refresh.swift`  
**Function:** `performIBKRSync()` — lines 133–136  
**What happens:** Three timers fire every 9, 19, and 29 minutes specifically to update live prices from the broker. All three dispatch to `performIBKRSync()`, which is empty. Live prices are never refreshed between full scan cycles.

---

### BUG-6: Brain Learn and Bias Are Empty Stubs
**File:** `Wealth Creation/WealthBrainStore.swift`  
**Functions:** `learn()` lines 70–72, `bias()` lines 74–77  
**What happens:** `performAIScan()` calls `WealthBrainStore.shared.ingest()`, which calls `learn()`. Since `learn()` is empty, the brain never updates its model from live trading data. `bias()` is never called anywhere in the committed codebase, so even if it had an implementation, it would not affect scoring.

---

### BUG-7: IBKR Message Handler Is Empty
**File:** `Wealth Creation/WealthIBKRBridge.swift`  
**Function:** `handleApiMessage(data:)` — lines 194–196  
**What happens:** After the handshake completes, every inbound TWS message (price ticks, account updates, order status, fills) is passed to this method and immediately discarded. The bridge is connected and talking to TWS but receives no usable data.

---

### BUG-8: Ready-State Notification Only Fires Once — Post-Ready Pipeline Runs Once
**File:** `Wealth Creation/WealthReadyStateGate.swift`  
**Function:** `markDownstreamRebuildComplete()` — lines 54–65  
**What happens:** The `if !wasReady && isFullyReady` guard means the `wealthEngineDidBecomeReady` notification is posted exactly once per app lifecycle — on the very first transition to ready. Every session-resume rebuild thereafter completes without triggering audits, without re-running the AI Live evaluation, and without saving updated file-backed caches. From the second session onward, the post-ready pipeline is a dead path.

---

### BUG-9: `restoreCache()` Decodes Large Arrays on Main Thread
**File:** `Wealth Creation/WealthEngineStore+Cache.swift`  
**Function:** `restoreCache()` — lines 65–76  
**What happens:** The function header comment says "Large array decoding is **not** performed here." The implementation then immediately calls `restoreRankedAssetsFromFile()`, `restoreScannedSignalsFromFile()`, and `restoreHoldingsFromFile()` — which each perform JSON decoding of potentially 128,000 records. This is the same main-thread freeze the `BackgroundCache` extension was designed to fix. Any call site that uses `restoreCache()` instead of `restoreCacheInBackground()` will freeze the UI on launch.

---

### BUG-10: `WealthPortfolioLifecycleHelper` Polls and Silently Fails
**File:** `Wealth Creation/WealthPortfolioStore+LifecycleHelpers.swift`  
**Function:** `scheduleArmedRetry(attemptsRemaining:)` — lines 71–91  
**What happens:** If `tradingLifecycleArmed` is not `true` when the engine-ready notification fires, the helper polls once per second for 30 attempts. If it never becomes true (because the flag is set inside the unauditable `WealthCore.swift` activation path), the helper logs a red entry and abandons Activity reconciliation permanently for that session. The heartbeat timer is mentioned as a fallback, but timers only trigger `refresh()`, not `rerunActivityAdmissionAfterStartup()`.

---

### BUG-11: `nonisolated(unsafe)` Global Timer Holder Bypasses Concurrency Safety
**File:** `Wealth Creation/WealthEngineStore+Timers.swift`  
**Declaration:** `private nonisolated(unsafe) let timerHolder = WealthTimerHolder()` — line 31  
**What happens:** `nonisolated(unsafe)` explicitly tells the Swift concurrency checker to ignore isolation requirements for this value. The comment says access is always serialized because the enclosing class is `@MainActor`, but `Timer.scheduledTimer` callbacks can be delivered on the run loop associated with the thread that called `scheduleRecurringTimers()` — and if that differs from the main thread, the `timerHolder` is accessed from an unguarded context. The annotation is a suppressed data-race warning, not a guarantee.

---

### BUG-12: All File Persistence Failures Are Silent
**Files:** `WealthEngineStore+Cache.swift`, `WealthEngineStore+BackgroundCache.swift`, `WealthDownstreamCacheSanity.swift`  
**Pattern:** Every `try? data.write(...)`, `try? JSONEncoder().encode(...)`, `try? Data(contentsOf:...)` across all three files  
**What happens:** When disk space is full, the Caches directory is unavailable, or a file is locked, persistence silently fails. The engine continues as if data was saved, the next launch finds an empty cache, and triggers a full 128k-row download with no explanation to the user or developer. `WealthDownstreamCacheSanity` adds error logging for one write path (`persistToFile`) but all other write and read paths remain unlogged on failure.

---

### BUG-13: ScanScheduler Progress Is Never Reset Between Cycles
**File:** `Wealth Creation/WealthEngineScanScheduler.swift`  
**Function:** `markPhaseComplete(_:)` — lines 69–91  
**What happens:** `markPhaseComplete()` guards against duplicate entries (`guard !completedPhases.contains(phase)`), so once a phase is marked complete it can never be marked complete again in the same app session. After the first startup completes, `currentProgress` stays at 1.0 permanently. The gate `hasReachedAILiveGate` always returns `true` for the rest of the session — meaning the progress gate that was added to prevent premature AI Live evaluation is functionally inactive from the second scan cycle onward.

---

### BUG-14: Downstream Rebuild Skips Research Feeds
**File:** `Wealth Creation/WealthDownstreamRebuildOrchestrator.swift`  
**Function:** `performDownstreamRebuild()` — lines 72–90  
**What happens:** The orchestrator runs AI scan then market ranking. Research feeds are not included. Since `performResearchFeeds()` is a stub this is currently harmless, but when research feeds are implemented, session-resume rebuilds will never update research intel — only the 30-minute deep-refresh timer will do so.

---

## The Technical Debt Story

The AWC engine was built in two distinct layers that have not been fully integrated. The first layer — `WealthCore.swift` and the original engine — holds all the working implementations: the actual universe loader, the AI scorer, the portfolio manager, the trading lifecycle. This file is not committed to the repository.

The second layer — the 33 extension files committed here — was built as a scaffolding repair to fix specific problems in the original: main-thread blocking, missing stale-cache detection, broken timer architecture, missing lifecycle wiring. Each extension file is clearly documented and individually sound in structure. The repair intent is clear and well-reasoned.

The critical gap is that the two layers are not yet connected at the execution level. The extension layer calls stub methods that are supposed to delegate to `WealthCore.swift`, but those stub bodies are empty — not because the developers forgot, but because the merge has not happened yet. The placeholders in `Opportunity+CardStateMachine.swift` are explicitly labeled as temporary and wrong. The empty `performUniverseScan()` body is explicitly labeled as the "designated call site" pending refactoring.

This means the engine in its current committed state goes through all the correct motions — startup sequence, timer scheduling, background threading, session lifecycle management — while producing no data, computing no scores, and making no trades. It is a fully-wired harness waiting for the engine to be plugged in.

The risks that accumulate from this state:

1. **Integration ambiguity.** When `WealthCore.swift` is eventually merged, there will be two implementations of every major function — the original synchronous ones and the new async extension wrappers. Determining which one is authoritative for each function will require careful per-function resolution, and any mistake will silently call the wrong version.

2. **Placeholder values in production gates.** The `earningsRisk` and `macroRisk` calculations are wrong by design and labeled as such. If the merge happens under time pressure, these temporary values may persist into a production build, causing the safeguard gate to silently misclassify cards.

3. **One-shot ready-state notification.** The `wealthEngineDidBecomeReady` mechanism that triggers all post-ready processing fires only once. This architectural gap means that from the second session onward, the audit and AI Live pipeline is dark — which is unlikely to be caught in early testing when most sessions are fresh launches.

4. **Invisible error budget.** Because all persistence failures are silent, the codebase has no visibility into how often writes fail, how often cache decodes fail, or how often the 128k-row download is triggered unnecessarily. In a production environment, bandwidth cost and latency are real consequences of these invisible failures.

5. **Unverifiable foundation.** The core implementations live outside version control. There is no way to audit them for the same threading, error-handling, or caching issues identified in the extension layer. Any audit of the committed code is necessarily incomplete.

---

## Top-Priority Findings at a Glance

| Priority | File | Location | Issue |
|----------|------|----------|-------|
| P0 | `WealthEngineStore+Refresh.swift` | `performUniverseScan()` L102–107 | Empty stub — no data ever loaded |
| P0 | `Opportunity+CardStateMachine.swift` | `earningsRisk` L63–74 | Wrong calculation driving safeguard gate |
| P0 | `Opportunity+CardStateMachine.swift` | `macroRisk` L75–88 | Wrong calculation driving safeguard gate |
| P0 | `WealthIBKRBridge.swift` | `handleApiMessage(data:)` L194–196 | All broker data silently discarded |
| P1 | `WealthReadyStateGate.swift` | `markDownstreamRebuildComplete()` L54–65 | Post-ready pipeline fires once only |
| P1 | `WealthEngineStore+Refresh.swift` | `performIBKRSync()` L133–136 | Live price sync is empty |
| P1 | `WealthBrainStore.swift` | `learn()` L70–72, `bias()` L74–77 | Brain never learns or applies bias |
| P1 | `WealthEngineStore+Refresh.swift` | `performResearchFeeds()` L128–131 | Research feeds never run |
| P2 | `WealthEngineStore+Cache.swift` | `restoreCache()` L65–76 | Decodes 128k cards on main thread despite comment saying it does not |
| P2 | `WealthPortfolioStore+LifecycleHelpers.swift` | `scheduleArmedRetry()` L71–91 | Activity admission silently abandoned if armed state never fires |
| P2 | `WealthEngineScanScheduler.swift` | `markPhaseComplete()` L69–91 | Progress gate permanently open after first cycle |
| P2 | `WealthEngineStore+Timers.swift` | `timerHolder` L31 | `nonisolated(unsafe)` bypasses concurrency safety |
| P3 | All persistence files | All `try?` write/read calls | Silent failures with no user or diagnostic feedback |
| P3 | `WealthDownstreamRebuildOrchestrator.swift` | `performDownstreamRebuild()` L72–90 | Research feeds excluded from session-resume rebuilds |
