# joezambito/AWC — Audit Issue Status

**Source report:** PR #42 — "Comprehensive audit report for joezambito/AWC" (2026-04-05)  
**Branch checked:** `main` (commit `1e1eb247` — Merge PR #27, 2026-04-04)  
**Status date:** 2026-04-05

---

## Critical Issues

| # | Issue | File / Location | Status |
|---|-------|----------------|--------|
| 1.1 | **Placeholder risk math drives live trading gates** — `earningsRisk` uses generic `risk` float; `macroRisk` uses `1 − probability`. Both are marked `⚠️ PLACEHOLDER` and acknowledged to produce incorrect safeguard decisions in production. | `Opportunity+CardStateMachine.swift` lines 65–88 | ❌ UNRESOLVED |
| 1.2 | **Ranked cards silently discarded** — `assignMarketRanks()` result stored in `let ranked` but was never written back to `rankedAssets`; every card kept rank 0, breaking AI Live evaluation and market snapshots. | `WealthEngineStore+Materialization.swift` `materializeMarketCandidates()` | ✅ **FIXED in this PR** — `rankedAssets = ranked` added |
| 1.3 | **Dual conflicting startup paths** — `runActivationSequence()` (Path A) and `bootstrap()→beginStartupSequence()` (Path B) both exist and can both be triggered, producing up to 12 concurrent timers and duplicate scan passes. | `WealthEngineStore+Activation.swift`, `WealthEngineStore+Bootstrap.swift`, `WealthEngineStartupController.swift` | ❌ UNRESOLVED |
| 1.4 | **`endDashboardRefreshFreeze()` called but not defined in committed code** — called in cancellation `defer` of `runActivationSequence()`; only exists in uncommitted `WealthCore.swift`. Repository does not compile standalone. | `WealthEngineStore+Activation.swift` line 61 | ❌ UNRESOLVED |
| 1.5 | **`reconcileActivityAdmissions()` called but not defined in committed code** — called in `rerunActivityAdmissionAfterStartup()`; only in uncommitted `WealthCore.swift`. | `WealthPortfolioStore+Lifecycle.swift` line 53 | ❌ UNRESOLVED |
| 1.6 | **`runStartupActivationScan()` and `runStartupMarketWarmup()` not defined in committed code** — both `await`-called inside `runActivationSequence()` background task; only in uncommitted `WealthCore.swift`. | `WealthEngineStore+Activation.swift` lines 89, 93 | ❌ UNRESOLVED |
| 1.7 | **`WealthBrainStore.learn()` and `bias()` are empty stubs** — `learn()` is called on every scan cycle but does nothing; `bias()` has no call site. Brain never accumulates learning. | `WealthBrainStore.swift` lines 71–79 | ❌ UNRESOLVED |
| 1.8 | **`performResearchFeeds()` and `performIBKRSync()` are empty stubs** — deep refresh and all IBKR price updates silently no-op every cycle. | `WealthEngineStore+Refresh.swift` lines 126–130 | ❌ UNRESOLVED |
| 1.9 | **`performUniverseScan()` is an empty stub** — entire universe scan pipeline terminates with no work done; all 128k card population depends on uncommitted `WealthCore.swift`. | `WealthEngineStore+Refresh.swift` lines 103–108 | ❌ UNRESOLVED |
| 1.10 | **`WealthIBKRBridge.handleApiMessage(data:)` is an empty stub** — IBKR connection establishes successfully but all incoming market data ticks, account updates, and order confirmations are silently dropped after handshake. | `WealthIBKRBridge.swift` line 194 | ❌ UNRESOLVED |
| 1.11 | **`downstreamRecoveryPending` set but never cleared** — flag is set `true` at the start of `runActivationSequence()` but no committed file ever sets it back to `false`; any gate on `downstreamRecoveryPending == false` is permanently blocked. | `WealthEngineStore+Activation.swift` line 52 | ❌ UNRESOLVED |
| 1.12 | **`nonisolated(unsafe)` timer holder bypasses Swift concurrency checks** — compiler cannot verify MainActor serialisation; future non-MainActor access would cause a silent data race on timer arrays. | `WealthEngineStore+Timers.swift` line 31 | ❌ UNRESOLVED |

---

## Security Issues (High Priority)

| # | Issue | File / Location | Status |
|---|-------|----------------|--------|
| S.1 | **Hardcoded LAN IP `192.168.1.21` in production log** — host address leaked in OSLog error message visible to any log consumer. | `WealthIBKRBridge+Send.swift` line 169 | ❌ UNRESOLVED |
| S.2 | **IBKR connection is plain TCP — no TLS, no authentication** — all financial data (market ticks, account positions, order confirmations) transmitted in cleartext over the local network. | `WealthIBKRBridge.swift` (NWConnection setup) | ❌ UNRESOLVED |
| S.3 | **Cache files written without `.completeFileProtection`** — on-disk card/signal/holding cache files are readable at rest on locked or jailbroken devices. | `WealthEngineStore+Cache.swift`, `WealthEngineStore+BackgroundCache.swift` | ❌ UNRESOLVED |
| S.4 | **GPG public key committed at repo root (`gpg_key.txt`)** — key material should not be tracked in source control. | `gpg_key.txt` (repo root) | ❌ UNRESOLVED |

---

## Previously Flagged — Already Fixed

| Issue | Fixed in | Notes |
|-------|----------|-------|
| **Scan timer / cycle bug** (overlapping timers from `startScanTimer` / `restartCycleTimer`) | PR #7 — commit `9d6e610` "Implement complete state-machine repair" (merged 2026-04-04) | `startScanTimer` and `restartCycleTimer` removed entirely. `rescheduleTimers()` always calls `invalidateTimers()` first, making overlapping timers architecturally impossible. |

---

## Summary

| Category | Total | Fixed | Unresolved |
|----------|-------|-------|-----------|
| Critical bugs | 12 | 1 (1.2, this PR) + 1 (timer bug, PR#7) | 10 |
| Security / High | 4 | 0 | 4 |
| **Total** | **16** | **2** | **14** |

The most impactful remaining issues to prioritise are:
1. **1.4 / 1.5 / 1.6** — commit `WealthCore.swift` so the repository builds standalone
2. **1.1** — replace placeholder `earningsRisk` / `macroRisk` with real earnings/macro data sources
3. **1.3** — resolve the dual startup path conflict
4. **S.2** — add TLS to the IBKR connection
