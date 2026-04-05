# Draft PR Audit — PRs #12, #13, #18, #19, #21

**Audit question:** Do any of these 5 draft PRs contain critical fixes required
for the brain integration in PR #27 ("Wire WealthBrainStore into recurring timer
scan pipeline")? Or are all 5 safe to close?

---

## Audit Matrix

| PR | Title | Files Changed | Critical Bug Fix? | Required for #27? | Action |
|----|-------|---------------|-------------------|-------------------|--------|
| **#12** | Map startup dependencies and fix missing engine-state finalisation in WealthEngineStartupController | `WealthEngineStartupController.swift` (+6/−1), `WealthEngineStartupDependencyMap.swift` (new, docs) | ⚠️ Yes — but fixes **Activity admission**, not brain integration | ❌ No | **CLOSE** |
| **#13** | Add comprehensive startup dependency map for AWC engine | `STARTUP_DEPENDENCY_MAP.md` (new, 660 lines) | ❌ No — documentation only | ❌ No | **CLOSE** |
| **#18** | Perf: fix timer duplication, split oversized file, reduce startup delays | `WealthEngineStartupController.swift`, `WealthEngineStore+Activation.swift`, `WealthEngineStore+Timers.swift`, `WealthDownstreamCacheSanity.swift`, `WealthDownstreamCacheSanity+Validation.swift` (new) | ❌ No — performance optimisation | ❌ No | **CLOSE** |
| **#19** | Audit: WealthEngineStore refactoring — function logic and feature preservation analysis | *(no code files changed — pure audit document PR)* | ❌ No | ❌ No | **CLOSE** |
| **#21** | Audit: document all four WealthEngineStore timer sequences | *(no code files changed — pure audit document PR)* | ❌ No | ❌ No | **CLOSE** |

**Result: Close all 5. Merge only #27.**

---

## Detailed Findings

### PR #12 — WealthEngineStartupController finalisation fix

**What it changes:**  
Adds `engine.finalizeActivationState()` before `engine.rescheduleTimers()` at
the end of `WealthEngineStartupController.runStartupSequence()`.

**The bug it fixes:**  
The new startup path (`WealthEngineStartupController`) never stamps the
`@Published` flags that downstream systems gate on:

```
activationCycleComplete = true    // gates downstream refreshes
tradingLifecycleArmed   = true    // gates WealthPortfolioStore Activity admission
lockedCheckpointProgress = ...
startupSequencePhase    = .idle
```

`WealthEngineStore+Activation.swift` (`runActivationSequence()`) *does* set
these flags, but that legacy path is no longer called from `bootstrap()` in the
current codebase. The result is `tradingLifecycleArmed` stays `false` until the
next 30-minute timer tick — blocking Activity admission for the first half hour.

**Does it break brain integration (#27)?**  
No. PR #27 calls `WealthBrainStore.shared.ingest(cycleComplete: activationCycleComplete)`.
`activationCycleComplete = false` is passed to `ingest()` — the brain still
receives all opportunities and still learns from each timer scan. Brain
integration is not blocked by this flag.

**Verdict:** Real bug, wrong PR for #27. Close #12. The Activity admission bug
should be addressed in a targeted follow-up PR against `main` if Activity cards
are needed immediately; otherwise it self-heals on the first 30-minute timer
tick via `rescheduleTimers()`.

---

### PR #13 — STARTUP_DEPENDENCY_MAP.md

**What it changes:** Adds a single 660-line markdown reference document.

**Does it affect #27?** No — documentation only, zero Swift code changes.

**Verdict:** Close.

---

### PR #18 — Timer teardown + file split + startup delay reduction

**What it changes:**

1. **Timer teardown** — replaces 8 manual `timer?.invalidate(); timer = nil`
   lines in `runActivationSequence()` with a single `invalidateTimers()` call.
   Also expands `invalidateTimers()` to cover `scheduledCheckpointTimer` and
   `preScanBurstTimer` (previously omitted).

2. **File split** — moves validation methods out of `WealthDownstreamCacheSanity.swift`
   into a new `WealthDownstreamCacheSanity+Validation.swift` extension.

3. **Startup delays** — reduces inter-phase `Task.sleep` gaps from 4 s total
   (2+1+1) to 2 s total (1+0.5+0.5).

**Does it break brain integration (#27)?**  
No. PR #27 adds `WealthBrainStore.shared.ingest()` to `performAIScan()`, which
is triggered by `softTimer` and `heavyTimer` callbacks. Neither the teardown
consolidation nor the delay reduction change *when* or *whether*
`performAIScan()` is called.

**Verdict:** Nice-to-have performance work. Close.

---

### PR #19 — Audit: WealthEngineStore refactoring analysis

**What it changes:** No Swift files — the GitHub diff is empty (0 changed
files, 0 additions, 0 deletions). This PR exists only as an agent-generated
audit report embedded in the PR body.

**Verdict:** No code. Close.

---

### PR #21 — Audit: four WealthEngineStore timer sequences

**What it changes:** No Swift files — the GitHub diff is empty (0 changed
files). Audit findings live only in the PR description.

**Verdict:** No code. Close.

---

## What #27 Needs to Work

PR #27 ("Wire WealthBrainStore into recurring timer scan pipeline") adds:

| File | Change |
|------|--------|
| `WealthBrainStore.swift` *(new)* | `@MainActor` singleton with `ingest()` |
| `WealthEngineStore+Refresh.swift` | `performAIScan()` calls `WealthBrainStore.shared.ingest(...)` |
| `WealthEngineStore+Timers.swift` | Timer factories accept `stage: Int` and set `activationStage` |
| `WealthNewComponentsBootstrap.swift` | `_ = WealthBrainStore.shared` initialises singleton at launch |

None of these changes depend on #12, #13, #18, #19, or #21 being merged first.
The brain integration compiles and functions against the current `main` branch
state.

---

## Recommended Actions

| Action | Target |
|--------|--------|
| ✅ **MERGE** | PR #27 — brain integration |
| ❌ **CLOSE** | PR #12 — engine finalisation (real bug, separate follow-up needed) |
| ❌ **CLOSE** | PR #13 — documentation only |
| ❌ **CLOSE** | PR #18 — performance optimisations |
| ❌ **CLOSE** | PR #19 — no code changes |
| ❌ **CLOSE** | PR #21 — no code changes |

### Follow-up (after merging #27)

The Activity admission bug from PR #12 is real. After merging #27, open a
small targeted PR that adds these 5 lines to the end of
`WealthEngineStartupController.runStartupSequence()` (before
`engine.rescheduleTimers()`):

```swift
// Stamp all @Published flags that downstream systems gate on
engine.activationCycleComplete   = true
engine.tradingLifecycleArmed     = true
engine.lockedCheckpointProgress  = WealthEngineStore.lockedCheckpointCount
engine.startupSequencePhase      = .idle
engine.downstreamRecoveryPending = false
```

This ensures Activity admission is not delayed until the first 30-minute timer
tick on every cold launch.
