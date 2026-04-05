# PR Merge / Delete Audit — #12 to #27

**Goal:** Keep only the minimal brain integration fix. Close all exploration, audit, and scope-creep PRs.

**Rule:** Only merge PRs that are essential for brain integration wiring or are critical bug fixes that block it. Everything else → CLOSE.

**Minimal fix target:** PR #27 — wires `WealthBrainStore.ingest()` into the recurring timer scan pipeline (4 files, ~120 lines added, 19 deleted).

---

## Quick Answer

| Action | PR Numbers |
|--------|-----------|
| ✅ MERGE | **#27** |
| ❌ CLOSE | #12, #13, #14, #15, #16, #17, #18, #19, #20, #21, #22, #23, #24, #25, #26 |

---

## Full Matrix

| PR | Title | Files Changed | Required for #27? | Conflicts / Scope Creep? | VERDICT |
|----|-------|---------------|-------------------|--------------------------|---------|
| **#12** | Map startup dependencies and fix missing engine-state finalisation in WealthEngineStartupController | `WealthEngineStartupController.swift` (+6/−1), `WealthEngineStartupDependencyMap.swift` (new doc) | ❌ No | Adds engine-state finalisation not related to brain wiring | ❌ CLOSE |
| **#13** | Add comprehensive startup dependency map for AWC engine | `STARTUP_DEPENDENCY_MAP.md` (new, 660 lines) | ❌ No | Documentation-only; no code | ❌ CLOSE |
| **#14** | Refactor WealthEngineStore: core state file + single checkpoint timer | `WealthEngineStore.swift` (new, 177 lines), `WealthEngineStore+Activation.swift`, `WealthEngineStore+Timers.swift` | ❌ No | **CONFLICTS** — switches to single-checkpoint-timer architecture; #27 depends on the existing 6-timer architecture (`softTimer`, `heavyTimer`, etc.) | ❌ CLOSE |
| **#15** | Audit: WealthEngineStore current structure documentation | *(no code — 0 files changed)* | ❌ No | Empty PR; audit only | ❌ CLOSE |
| **#16** | Audit: WealthEngineStore structure analysis | *(no code — 0 files changed)* | ❌ No | Empty PR; audit only | ❌ CLOSE |
| **#17** | Fix stale timer teardown in runActivationSequence + document dual startup paths | `WealthEngineStore+Activation.swift`, `WealthEngineStore+Bootstrap.swift`, `WealthEngineStore+Timers.swift` | ❌ No | Fixes a separate timer-teardown bug + adds header comments. Brain integration does not need this first. | ❌ CLOSE |
| **#18** | Perf: fix timer duplication, split oversized file, reduce startup delays | `WealthDownstreamCacheSanity.swift`, `WealthDownstreamCacheSanity+Validation.swift` (new), `WealthEngineStartupController.swift`, `WealthEngineStore+Activation.swift`, `WealthEngineStore+Timers.swift` | ❌ No | Scope creep — performance optimisation (halves startup delays), file splits. Touches `+Timers.swift`, same file #27 modifies → likely conflict | ❌ CLOSE |
| **#19** | Audit: WealthEngineStore refactoring — function logic and feature preservation analysis | *(no code — 0 files changed)* | ❌ No | Empty PR; audit only | ❌ CLOSE |
| **#20** | Fix duplicate timer teardown and enforce layered startup via WealthEngineStore+Activation | `WealthEngineStore+Activation.swift` | ❌ No | Refactor — replaces `runActivationSequence()` body with single `WealthEngineStartupController.shared.beginStartupSequence()` call. Not needed for brain wiring. | ❌ CLOSE |
| **#21** | Audit: document all four WealthEngineStore timer sequences | *(no code — 0 files changed)* | ❌ No | Empty PR; audit only | ❌ CLOSE |
| **#22** | Add timer scan data audit report | `TIMER_SCAN_AUDIT.md` (new, 288 lines) | ❌ No | Documentation-only; no code | ❌ CLOSE |
| **#23** | Audit: document exact data flow through performAIScan() at each timer mark | *(no code — 0 files changed)* | ❌ No | Empty PR; audit only | ❌ CLOSE |
| **#24** | feat: implement performResearchFeeds() – research intel pipeline for ranked cards | `WealthEngineStore+Recovery.swift`, `WealthEngineStore+Refresh.swift`, `WealthResearchCard.swift` (new), `WealthResearchFeedEngine.swift` (new), `WealthResearchIntelStore.swift` (new) | ❌ No | New feature (research intel pipeline). Modifies `+Refresh.swift`, same file #27 modifies → **CONFLICT**. Out of scope for minimal fix. | ❌ CLOSE |
| **#25** | Implement AI brain and advanced brain coordinators; wire performAIScan/performResearchFeeds/performIBKRSync stubs | `WealthAIBrainCoordinator.swift` (new), `WealthEngineStore+Refresh.swift`, `WealthResearchFeedCoordinator.swift` (new) | ❌ No | Implements scoring logic in `performAIScan()` — **CONFLICTS** with #27 which adds a different call to that same function. Also adds new feature files (brain coordinators). Scope creep. | ❌ CLOSE |
| **#26** | Wire WealthBrainStore into recurring timer scan pipeline | `WealthBrainStore.swift` (new), `WealthEngineStore+Refresh.swift`, `WealthEngineStore+Timers.swift`, `WealthNewComponentsBootstrap.swift` | ✅ Yes (duplicate) | **Duplicate of #27** — identical files and changes. #27 is the more recent version. Close #26 to avoid double-merge. | ❌ CLOSE (duplicate) |
| **#27** | Wire WealthBrainStore into recurring timer scan pipeline | `WealthBrainStore.swift` (new, 78 lines), `WealthEngineStore+Refresh.swift` (+8), `WealthEngineStore+Timers.swift` (+33/−19), `WealthNewComponentsBootstrap.swift` (+1) | ✅ YES — this IS the fix | Minimal change only. No logic modified. Only adds the brain ingest call + stage tracking. | ✅ MERGE |

---

## What #27 Does (Brain Integration Only)

#27 adds exactly 4 changes — nothing else:

1. **`WealthBrainStore.swift`** *(new)* — defines the `@MainActor` singleton with `ingest()` as the scan pipeline connection point. `learn()` and `bias()` remain stubs matching the `WealthCore.swift` override pattern.

2. **`WealthEngineStore+Refresh.swift`** — adds `WealthBrainStore.shared.ingest(...)` call inside the existing `performAIScan()` stub. No other logic changed.

3. **`WealthEngineStore+Timers.swift`** — timer factory functions (`makeIBKRTimer`, `makeSoftTimer`, `makeDeepTimer`) each gain a `stage: Int` parameter. Each callback sets `activationStage` on `@MainActor` before dispatching the detached refresh, establishing the 6-stage cycle: `ibkr1=0 → soft1=1 → ibkr2=2 → soft2=3 → ibkr3=4 → deep=5`.

4. **`WealthNewComponentsBootstrap.swift`** — adds `_ = WealthBrainStore.shared` to `activate()` so the singleton is initialised at launch alongside the rest of the pipeline.

---

## Why to Close Each Category

### Empty / Audit-only PRs (no code changes)
**Close: #15, #16, #19, #21, #23**

These PRs have **zero files changed**. They were created to document findings during exploration sessions. No code was committed, so closing them costs nothing.

### Documentation-only PRs
**Close: #13, #22**

Only add Markdown files (`STARTUP_DEPENDENCY_MAP.md`, `TIMER_SCAN_AUDIT.md`). Useful references but not required for brain wiring. Can be re-added later if desired.

### Conflicting Architecture PRs
**Close: #14**

PR #14 switches to a completely different timer architecture (single `scheduledCheckpointTimer` instead of the 6-timer set). This directly conflicts with #27, which depends on the existing `softTimer`/`heavyTimer`/IBKR timer architecture. Merging #14 before #27 would break #27.

### Bug-fix / Refactor PRs (unrelated to brain)
**Close: #12, #17, #18, #20**

These fix real issues (timer teardown, startup sequence, performance) but none of them are required for `WealthBrainStore.ingest()` to work. They are follow-on improvements and can be revisited as separate PRs after the brain integration is live.

### New Feature PRs (scope creep)
**Close: #24, #25**

These implement `performResearchFeeds()` and `WealthAIBrainCoordinator` scoring logic — useful future work, but the user's rule is "minimal fix only, no extra changes." Both modify `WealthEngineStore+Refresh.swift`, the same file #27 modifies, causing a merge conflict.

### Duplicate PR
**Close: #26**

Identical to #27 (same 4 files, same diffs, same brain ingest wiring). Keep #27 (newer), close #26.

---

## How to Execute

1. **Open GitHub → joezambito/AWC → Pull Requests**
2. Click **#27** → click **"Ready for review"** → then **Merge pull request**
3. For each of #12–#26: open the PR → scroll to bottom → click **"Close pull request"** (do NOT merge)

That's it. After closing 15 PRs and merging #27, your brain is wired in and the PR list is clean.
