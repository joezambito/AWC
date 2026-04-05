# AWC Audit Status — Scan Timer/Cycle Bug

## Why the Scan Timer Bug Appeared as Unresolved in the Report

**Short answer:** The report description was generated from stale pre-fix chat-session summaries, not from the committed code. The actual audit document (AUDIT_REPORT.md) correctly reflects the current codebase. The bug is fixed.

---

## Root Cause — Precise Technical Explanation

### Timeline

| Timestamp (UTC)        | Event |
|------------------------|-------|
| 2026-04-04 07:06:01    | Commit `9d6e610` pushed on PR #7 branch — removes `startScanTimer` / `restartCycleTimer`, introduces `rescheduleTimers() → invalidateTimers() → scheduleRecurringTimers()` |
| 2026-04-04 07:10:07    | PR #7 merged to `main` |
| 2026-04-05 02:40–03:15 | Audit PRs #38–42 created by a Copilot session asked to "review both prior audit reports" |

### What went wrong

The Copilot session that produced PR #38 was asked to synthesise findings from **two prior chat-session audit passes**. Those prior passes had been run against the codebase **before PR #7 was merged**. The synthesis session recycled the findings from those earlier sessions — including the `startScanTimer` / `restartCycleTimer` overlap bug — without re-reading the committed files on `main`.

This created a split between two artefacts in the same PR:

| Artefact | Based on | Timer finding |
|----------|----------|---------------|
| **PR #38 description / body** | Stale pre-PR#7 chat summaries | ❌ Cites `startScanTimer` / `restartCycleTimer` (functions that no longer exist) |
| **Committed `AUDIT_REPORT.md`** | Actual committed files in `Wealth Creation/` | ✅ Correctly identifies BUG-11 — the `nonisolated(unsafe)` timerHolder annotation — a separate, current concern |

The PR body description was the visible artefact; the committed document was the accurate one. The bug citation in the PR body was noise carried over from pre-fix analysis.

### Verification — The Fix Is Live on `main`

`Wealth Creation/WealthEngineStore+Timers.swift` on `main` (as of commit `1e1eb24`, SHA `c3ebb04`) contains **no** `startScanTimer` or `restartCycleTimer` functions. The file exposes only:

```
rescheduleTimers()         // public entry point
  └─ invalidateTimers()    // cancels every existing timer before any new one is created
  └─ scheduleRecurringTimers()  // schedules fresh timers
```

Overlapping timers are architecturally impossible: `invalidateTimers()` explicitly calls `.invalidate()` and `.removeAll()` on every timer reference — IBKR timers, extra soft timers, `softTimer`, and `heavyTimer` — before a single new timer is created.

---

## Actual Open Timer Finding (BUG-11 from AUDIT_REPORT.md)

The committed audit report does flag one timer-related concern that **is** present in the current code:

> **BUG-11 — `nonisolated(unsafe)` global timer holder bypasses concurrency safety**  
> `private nonisolated(unsafe) let timerHolder = WealthTimerHolder()` — `WealthEngineStore+Timers.swift` line 31  
> The annotation tells the Swift concurrency checker to ignore isolation requirements for this value. The comment asserts that access is always serialised on `@MainActor`, but `Timer.scheduledTimer` callbacks fire on the run loop of the thread that scheduled them. If `scheduleRecurringTimers()` is ever called off the main thread, `timerHolder` is accessed without isolation.

This is distinct from the resolved overlapping-timer bug. It is a data-race suppression concern, not a timer accumulation concern.

---

## How to Avoid Report/Code Mismatches in Future

1. **Pin every audit to a commit SHA.** Before running any audit, record `git rev-parse HEAD` or the merge commit SHA of the latest `main`. Include that SHA in the report header so readers can verify which state was analysed.

2. **Never recycle prior chat-session summaries as current findings.** Each audit session must read the committed files directly. Chat context from sessions predating a significant merge is stale by definition.

3. **Run a fresh audit after every major merge.** If two or more significant PRs land in a short window (as PRs #7–10 did on 2026-04-04), queue a single fresh audit pass against the post-merge `main` tip before publishing any findings.

4. **Cross-check "already known" bugs against the committed code** before including them in a synthesis. A one-line `grep` for the function name is sufficient — if the function no longer exists, the finding is resolved.

---

## Status Summary

| Finding | Status |
|---------|--------|
| Scan timer overlap (`startScanTimer` / `restartCycleTimer`) | ✅ **Fixed** — PR #7, commit `9d6e610`, merged 2026-04-04 |
| BUG-11 `nonisolated(unsafe)` timerHolder | ⚠️ **Open** — present in current `WealthEngineStore+Timers.swift` |
| All other findings in AUDIT_REPORT.md | See committed `AUDIT_REPORT.md` for current status |

The overall audit report (AUDIT_REPORT.md) is accurate. Only the PR body description for PRs #38–42 contained stale pre-fix citations — the committed document itself does not.
