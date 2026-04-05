# AWC — Deep Audit Report

**Audited commit:** `26115eb` (branch `copilot/conduct-full-deep-audit`)  
**Audit date:** 2026-04-05  
**Scope:** All 40 Swift source files in `Wealth Creation/`, `Tests/AWCTests/AWCTests.swift`,
`.github/workflows/swift.yml`, `Package.swift`, `Package.resolved`, `.gitignore`,
`.env.example`, `gpg_key.txt`, `README.md`, `ARCHITECTURE.md`, `AUDIT_STATUS.md`, `SETUP.md`.

> **Audit rule:** No code, logic, function, or behaviour changes were made during this audit.
> All findings are observations only.

---

## Table of Contents

1. [Summary table](#summary-table)
2. [Critical findings](#critical-findings)
3. [High findings](#high-findings)
4. [Medium findings](#medium-findings)
5. [Low findings](#low-findings)
6. [Informational notes](#informational-notes)

---

## Summary table

| ID | Severity | File | Short description |
|----|----------|------|-------------------|
| C-1 | 🔴 Critical | `WealthEngineStore+Materialization.swift:97` | `ranked` is a dead assignment — computed ranks are never published |
| C-2 | 🔴 Critical | `Opportunity+CardStateMachine.swift:71,85` | `earningsRisk` and `macroRisk` are placeholder formulae that produce wrong safeguard decisions |
| C-3 | 🔴 Critical | `WealthEngineStore+Refresh.swift:103,129,134` | `performUniverseScan`, `performResearchFeeds`, `performIBKRSync` are empty stubs — core scans are no-ops |
| C-4 | 🔴 Critical | `WealthBrainStore.swift:94,99` | `learn()` and `bias()` are empty stubs — the AI brain never learns or biases |
| C-5 | 🔴 Critical | `WealthAppSessionController.swift:153` | `WealthEngineStore.shared.save()` is called but `save()` is not defined in any committed source |
| H-1 | 🟠 High | `gpg_key.txt` (repo root) | PGP public key committed despite explicit `.gitignore` entry |
| H-2 | 🟠 High | `WealthEngineStore+Timers.swift:31`, `WealthIBKRBridge.swift:62` | `nonisolated(unsafe)` bypasses Swift actor-isolation on two shared objects |
| H-3 | 🟠 High | `WealthPeerSyncService.swift:80,111` | `NWListener` and `NWBrowser` started on `queue: .main` — floods the main queue |
| H-4 | 🟠 High | `.github/workflows/swift.yml:13` | CI runs on `ubuntu-latest` — cannot build or validate the iOS/Mac Catalyst Xcode target |
| H-5 | 🟠 High | `AUDIT_STATUS.md` (lines 5, 18, 40, 50) | References `AUDIT_REPORT.md` as an existing committed document, but that file does not exist |
| M-1 | 🟡 Medium | `WealthNewComponentsBootstrap.swift` | `WealthStaleCacheDetector.shared` is never activated in `activate()` |
| M-2 | 🟡 Medium | `WealthPortfolioStore+LifecycleHelpers.swift:88` | Recursive retry Tasks overwrite `retryTask` without cancelling the previous handle |
| M-3 | 🟡 Medium | Multiple files | Core types (`WealthMarketUniverseStore`, `WealthPortfolioStore`, `WealthAllCardsStore`, `WealthEventLogStore`, `WealthCardHoldingRouter`) are referenced but defined only in uncommitted `WealthCore.swift` |
| L-1 | 🔵 Low | `WealthIBKRBridge+Send.swift:53` | `subscribeMarketData` does not validate `contract.exchange` or `contract.currency` |
| L-2 | 🔵 Low | `WealthPeerSyncService.swift:82` | NWListener init failure is only logged to OSLog — not to `WealthEventLogStore` |
| L-3 | 🔵 Low | `WealthEngineStore+Timers.swift:96–133` | Timer callbacks create an untracked inner `Task` — if `self` is released the timer continues firing |
| L-4 | 🔵 Low | `WealthEngineStore+Timers.swift:31` | `WealthTimerHolder` is a file-private class with mutable state under `nonisolated(unsafe)` — race possible if ever called off-main |
| L-5 | 🔵 Low | `Tests/AWCTests/AWCTests.swift` | No test coverage for the materialization pipeline, safeguard gate, or card state-machine |

---

## Critical findings

### C-1 — `ranked` is a dead assignment; computed ranks are never published

**File:** `Wealth Creation/WealthEngineStore+Materialization.swift`  
**Line:** 97

```swift
let ranked = assignMarketRanks(to: recheckPassed)   // line 97 – DEAD ASSIGNMENT

WealthAllCardsStore.shared.sync(
    opportunities: rankedAssets,                    // line 100 – uses the UNRANKED original
    ...
)
```

**What is wrong:** `assignMarketRanks(to:)` computes fresh integer ranks (1, 1, 2, 3, …) for every
candidate and stores the result in `ranked`. Immediately afterward, `WealthAllCardsStore.shared.sync()`
is called with `rankedAssets` — the original, unmodified `@Published` property — instead of `ranked`.
The freshly computed ranks are silently discarded. Additionally, `rankedAssets` itself is never updated
inside this method, so the `@Published` property continues to expose the stale ranks from the previous
scan cycle.

**Performance and reliability impact:**
- The `assignMarketRanks(to:)` function executes on every materialization cycle but its output is
  never consumed, wasting CPU.
- The UI always displays ranks from the previous scan cycle, not the just-completed one.
  Rank 1 cards shown in the dashboard may not actually be the current top-ranked candidates.
- Downstream consumers (`WealthAILiveCoordinator`, Activity queue) receive cards with stale ranks,
  meaning AI Live may promote or demote the wrong cards.
- The materialization pipeline silently succeeds while producing an incorrect result, with no error
  log or assertion to indicate the discarded computation.

---

### C-2 — `earningsRisk` and `macroRisk` are placeholder formulae

**File:** `Wealth Creation/Opportunity+CardStateMachine.swift`  
**Lines:** 71–80 (`earningsRisk`), 85–92 (`macroRisk`)

```swift
/// ⚠️ PLACEHOLDER – Replace this computed property …
/// The current derivation from the generic `risk` float is NOT semantically
/// equivalent to earnings-specific risk and WILL produce incorrect safeguard
/// decisions in production until replaced.
var earningsRisk: Int {
    Int((risk * 100).rounded())   // generic risk re-labelled as earnings risk
}

/// ⚠️ PLACEHOLDER – Replace this computed property …
/// The current inverted-probability calculation is NOT semantically
/// equivalent to macro risk and WILL produce incorrect safeguard
/// decisions in production until replaced.
var macroRisk: Int {
    Int(((1.0 - probability) * 100).rounded())   // inverted probability, not macro risk
}
```

**What is wrong:** Both properties are explicitly documented in the code as placeholders that produce
semantically incorrect values. `earningsRisk` re-uses the generic `risk` field (which measures
general position risk, not earnings-calendar exposure). `macroRisk` inverts `probability` (a
trading-confidence score) and treats the inverse as macro/geopolitical risk, which is not equivalent.

**Performance and reliability impact:**
- Every card passes through the safeguard gate in `WealthEngineStore+Materialization.swift`
  (`evaluateSafeguards(for:)`) using these values. The gate rejects cards when
  `earningsRisk >= 70` or `macroRisk >= 75`.
- Because both thresholds are derived from unrelated fields, cards that should be blocked by real
  earnings or macro risk may pass the gate, and legitimately strong cards may be wrongly rejected.
- This silently corrupts the ranked candidate set fed to Activity and AI Live on every cycle.
- There is no runtime warning, log entry, or UI indicator when these placeholder values cause a
  rejection, making the errors invisible during normal operation.

---

### C-3 — Core scan stubs are empty; universe scan, research feeds, and IBKR price sync never run

**File:** `Wealth Creation/WealthEngineStore+Refresh.swift`  
**Lines:** 103–107 (`performUniverseScan`), 129–131 (`performResearchFeeds`), 134–136 (`performIBKRSync`)

```swift
@MainActor
func performUniverseScan() {
    // Implemented in WealthCore.swift (existing engine logic).
}

@MainActor
func performResearchFeeds() {
    // Appends research-feed intel to ranked cards.
}

@MainActor
func performIBKRSync() {
    // Price-only sync via IBKR bridge.
}
```

**What is wrong:** All three methods are empty. Every code path that calls them —
`runSoftRefresh()`, `runDeepRefresh()`, `runIBKRPriceSync()`, and all six timer callbacks — invokes
these methods but gets no work done. The comment "Implemented in WealthCore.swift" is a deferral,
not an implementation.

**Performance and reliability impact:**
- The universe is never refreshed via the timed pipeline; `rankedAssets` can only be populated from
  the cached snapshot restored on launch.
- Research-feed intelligence (analyst data, news scoring) is never appended to ranked cards, so AI
  Live scores lack that input permanently.
- The 9-minute, 19-minute, and 29-minute IBKR price-sync timers fire but do nothing, so live bid/ask
  prices are never updated during a session.
- The soft (10-min, 20-min) and deep (30-min) timer cycles also complete without updating the universe
  or research data. The dashboard shows stale data throughout every session beyond the initial launch.

---

### C-4 — `WealthBrainStore.learn()` and `bias()` are empty stubs

**File:** `Wealth Creation/WealthBrainStore.swift`  
**Lines:** 94–97 (`learn`), 99–102 (`bias`)

```swift
func learn() {
    // Implemented in WealthCore.swift (existing engine logic).
}

func bias() {
    // Implemented in WealthCore.swift (existing engine logic).
}
```

**What is wrong:** `ingest()` calls `learn()` on every soft and deep refresh cycle.
`learn()` is an empty stub. `bias()` is defined but never called by any committed code.

**Performance and reliability impact:**
- The brain's learning model is never updated regardless of how many scan cycles occur.
- `ingest()` logs a "Brain Ingest" event to `WealthEventLogStore` on every cycle, implying to
  operators that learning is happening when it is not.
- Card scoring will remain static (no bias applied) throughout the entire runtime of the app beyond
  what was persisted in WealthCore.swift at build time.

---

### C-5 — `WealthEngineStore.shared.save()` is called but the method is not defined in any committed source

**File:** `Wealth Creation/WealthAppSessionController.swift`  
**Line:** 153

```swift
func applicationWillTerminate() {
    WealthEngineStore.shared.save()   // 'save()' not defined in any committed file
    ...
}
```

**What is wrong:** No committed Swift file in `Wealth Creation/` defines a `save()` method on
`WealthEngineStore`. Only `saveInBackground()` (in `WealthEngineStore+BackgroundCache.swift`) and
`WealthEngineStore+Cache.swift` (which defines `restoreCache()` and `clearPersistedCache()`) are
present. `save()` must be defined in the uncommitted `WealthCore.swift`. If that file is absent or
the method is renamed, the Xcode build will fail with a "value of type 'WealthEngineStore' has no
member 'save'" error.

**Performance and reliability impact:**
- If `WealthCore.swift` is not present, the entire Xcode app target fails to compile.
- Even if the build succeeds (WealthCore.swift is present), the compile-time dependency is invisible
  to CI (which only runs the SPM test target against `Tests/AWCTests/`) meaning this call is
  **never validated by automated tests**.
- On a clean termination, state may not be persisted if `save()` is missing or incorrectly defined.

---

## High findings

### H-1 — `gpg_key.txt` is committed to the repository despite explicit `.gitignore` entry

**File:** `gpg_key.txt` (repository root)

**What is wrong:** `.gitignore` contains the entry `gpg_key.txt` on the last line, yet the file is
tracked and committed. The file contains a PGP public key block including the developer's full name
and GitHub email address (`joezambito@github.com`).

**Performance and reliability impact:**
- A PGP public key is not a secret on its own; it is designed to be shared. However, committing it
  to the repository while listing it in `.gitignore` is inconsistent — either the file should be
  committed intentionally (in which case the `.gitignore` entry should be removed) or it should be
  removed from the repository history.
- The presence of the file creates confusion: CI or tooling that respects `.gitignore` may behave
  differently from tooling that reads the tracked file list, because `.gitignore` only prevents
  *untracked* files from being staged; once tracked, the file is committed regardless of the
  `.gitignore` rule.
- If this pattern is followed for files that contain actual private keys, those secrets would also
  appear in the repository history even after being added to `.gitignore`.

---

### H-2 — `nonisolated(unsafe)` bypasses Swift actor-isolation on two shared mutable objects

**Files and lines:**
- `Wealth Creation/WealthEngineStore+Timers.swift:31` — `private nonisolated(unsafe) let timerHolder`
- `Wealth Creation/WealthIBKRBridge.swift:62` — `private nonisolated(unsafe) static let ibkrNetworkQueue`

```swift
// Timers.swift
private nonisolated(unsafe) let timerHolder = WealthTimerHolder()

// WealthIBKRBridge.swift
private nonisolated(unsafe) static let ibkrNetworkQueue = DispatchQueue(
    label: "com.awc.ibkr-bridge",
    qos: .userInitiated
)
```

**What is wrong:** `nonisolated(unsafe)` tells the Swift concurrency checker to stop enforcing actor
isolation for these declarations. The comments in both files assert that access is always serialised
on `@MainActor` at runtime.

For `timerHolder`: `Timer.scheduledTimer` schedules timers on the run loop of the *calling* thread.
If `scheduleRecurringTimers()` is ever invoked from a thread that is not the main thread (for
example, from inside a `Task.detached` callback that happens to be on the main actor but has not
yet hopped, or from a recovery path), the timer callbacks fire on that thread. The callbacks
immediately wrap their work in `Task { @MainActor in ... }` — but the timer callbacks themselves,
including the `guard let self` check and the `timerHolder` array accesses in `invalidateTimers()`,
execute outside of `@MainActor` isolation.

For `ibkrNetworkQueue`: `DispatchQueue` is a value type internally but the queue itself is a
reference type. The `nonisolated(unsafe)` annotation means that Swift will not enforce that this
is only accessed from a single actor, accepting the programmer's assertion that it is safe.

**Performance and reliability impact:**
- If `timerHolder` is mutated from two threads simultaneously (e.g. `rescheduleTimers()` on main
  and a timer callback on a background thread), the `[Timer]` arrays may corrupt, leading to timers
  that are never invalidated (accumulating duplicate timers) or to a crash from concurrent array
  mutation.
- Undetected timer accumulation causes repeated redundant scan cycles on every interval, multiplying
  network and CPU load.
- The concurrency checker is disabled for these declarations, so future callers that violate the
  stated assumptions will not receive a compile-time warning.

---

### H-3 — `NWListener` and `NWBrowser` in `WealthPeerSyncService` started on `queue: .main`

**File:** `Wealth Creation/WealthPeerSyncService.swift`  
**Lines:** 80 (NWListener `start`), 111 (NWBrowser `start`)

```swift
// line 80
l.start(queue: .main)

// line 111
b.start(queue: .main)
```

**What is wrong:** Both the Bonjour advertiser (NWListener) and the peer browser (NWBrowser) are
started with the main dispatch queue as their delivery queue. All NWListener and NWBrowser
callbacks (`stateUpdateHandler`, `newConnectionHandler`, `browseResultsChangedHandler`) fire on
`.main`. This is the same category of bug that was identified and fixed in `WealthIBKRBridge.swift`,
where `conn.start(queue: .main)` was replaced with a private background queue.

The callbacks themselves wrap their work in `Task { @MainActor in self?.handleX(state) }`, meaning
the intent was to run handling on `@MainActor`. However, the *delivery* queue still floods the main
dispatch queue with every TCP-level framework event from Bonjour/mDNS, including multicast
responses from every visible Bonjour service on the LAN.

**Performance and reliability impact:**
- During app startup, when `WealthPeerSyncService.start()` is called alongside the universe
  download and AI scan, Bonjour multicast discovery responses arrive continuously on the main queue,
  competing with UI event processing, startup tasks, and timer scheduling.
- On a busy LAN with many Bonjour services, the main queue can receive dozens of callbacks per
  second from `browseResultsChangedHandler`, causing measurable lag in the dashboard and Activity tab.
- Startup scan phases that need main-actor time (e.g. materialising ranked assets) may stall while
  the main queue drains Bonjour events, identical to the stall observed before the IBKR bridge fix.

---

### H-4 — CI runs on `ubuntu-latest`; Xcode app target is never built or validated

**File:** `.github/workflows/swift.yml:13`

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
```

**What is wrong:** AWC is an iOS/Mac Catalyst Xcode application. Ubuntu cannot run Xcode, and
`swift test` on Ubuntu only compiles and runs the SPM test target (`Tests/AWCTests/`) which does
not include any source files from `Wealth Creation/`. The 40 Swift files that form the actual app
are **never compiled or tested by CI**.

This means:
- All critical bugs in the `Wealth Creation/` source files (C-1 through C-5) are invisible to CI.
- The `nonisolated(unsafe)` data-race risks (H-2) are invisible to CI.
- API calls that depend on `WealthCore.swift` (e.g. `save()` in C-5) are never link-checked.
- Any future syntax error or type mismatch introduced in the 40 app-source files will not be caught
  by CI until a developer attempts a local Xcode build.

**Performance and reliability impact:**
- CI provides a false sense of validation: the `✅ All tests passed` status in GitHub only reflects
  the isolated SPM test suite, not the app itself.
- Regressions introduced by any PR that touches `Wealth Creation/` source will not be caught until
  a human builds the Xcode project locally.
- To validate the Xcode app target, CI needs a `macos-latest` runner with Xcode and a build step
  such as `xcodebuild build -scheme "Wealth Creation" ...`.

---

### H-5 — `AUDIT_STATUS.md` references `AUDIT_REPORT.md` as an existing document, but that file does not exist

**File:** `AUDIT_STATUS.md`  
**Affected lines:** 5, 18, 40, 50

```
The actual audit document (AUDIT_REPORT.md) correctly reflects the current codebase.
| **Committed `AUDIT_REPORT.md`** | Actual committed files in `Wealth Creation/` | ✅ Correctly identifies…
| All other findings in AUDIT_REPORT.md | See committed `AUDIT_REPORT.md` for current status |
The overall audit report (AUDIT_REPORT.md) is accurate.
```

**What is wrong:** `AUDIT_STATUS.md` was written to defend against a stale-finding citation by
pointing readers to a committed `AUDIT_REPORT.md`. However, that file has never been created in the
repository. All four references are broken.

**Performance and reliability impact:**
- Any developer, auditor, or reviewer following the instructions in `AUDIT_STATUS.md` to read
  `AUDIT_REPORT.md` will find a 404 / file-not-found. The claimed verification trail for the timer
  bug resolution and all other audit findings is inaccessible.
- The discrepancy makes it harder to assess which issues are resolved and which are open, increasing
  the time needed for future audits and code reviews.

---

## Medium findings

### M-1 — `WealthStaleCacheDetector` is never activated in `WealthNewComponentsBootstrap.activate()`

**File:** `Wealth Creation/WealthNewComponentsBootstrap.swift`

```swift
static func activate() {
    // ... touches singletons ...
    _ = WealthDownstreamCacheSanity.shared
    _ = WealthMarketExecutionAudit.shared
    // ... (10 other singletons) ...
    // WealthStaleCacheDetector.shared  ← MISSING
}
```

**What is wrong:** Every other new pipeline singleton is explicitly activated by calling
`_ = SomeType.shared` inside `activate()` so that its `init()` runs and any `NotificationCenter`
observers register. `WealthStaleCacheDetector` is the one exception. It does not register any
`NotificationCenter` observers in `init()`, so the missing activation call is non-critical in the
current implementation. However, the pattern is inconsistent: if a future developer adds an
observer in `WealthStaleCacheDetector.init()`, it will silently never fire because the singleton is
not activated here.

Additionally, `WealthStaleCacheDetector` is called only from `WealthSessionUnlockController`, which
is itself activated via `WealthPortfolioLifecycleHelper.shared` (which is activated). The actual
functionality is therefore reachable, but the discrepancy from the bootstrap pattern could mislead
future developers.

**Performance and reliability impact:**
- Currently low, because `WealthStaleCacheDetector` has no `init`-time observers.
- If staleness detection is extended to observe `wealthEngineDidBecomeReady` or similar
  notifications directly, those observers will never register until the bootstrap is corrected.

---

### M-2 — Recursive `scheduleArmedRetry()` overwrites `retryTask` without cancelling the previous handle

**File:** `Wealth Creation/WealthPortfolioStore+LifecycleHelpers.swift`  
**Line:** 88

```swift
private func scheduleArmedRetry(attemptsRemaining: Int) {
    guard attemptsRemaining > 0 else { ... return }

    retryTask = Task { [weak self] in        // overwrites retryTask
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        guard !Task.isCancelled, let self else { return }
        if WealthPortfolioStore.shared.tradingLifecycleArmed {
            self.triggerAdmissionRerun()
        } else {
            self.scheduleArmedRetry(attemptsRemaining: attemptsRemaining - 1)
            // ^^^ creates a NEW Task and overwrites retryTask again
        }
    }
}
```

**What is wrong:** Each recursive call to `scheduleArmedRetry(attemptsRemaining:)` creates a new
`Task` and assigns it to `retryTask`, overwriting the previous handle without calling `.cancel()`
on it. The previous task continues sleeping in the background with no tracked reference.

After 30 recursive calls, 29 abandoned Task handles are sleeping in the background. They will wake,
check `Task.isCancelled` (which is `false` because they were not cancelled), find `self` is still
alive, and potentially call `triggerAdmissionRerun()` or start more recursion.

`triggerAdmissionRerun()` *does* cancel `retryTask` before running — but by that point, `retryTask`
holds only the *last* task handle; all 29 prior tasks are uncancellable.

**Performance and reliability impact:**
- Up to 30 concurrent sleeping Tasks may accumulate per `handleEngineReady()` invocation.
- If the engine-ready notification fires multiple times (e.g. after a factory reset and re-startup),
  the count compounds.
- Each sleeping Task holds a `[weak self]` capture; if the object is alive, they can all call
  `triggerAdmissionRerun()` independently, causing up to 30 redundant `rerunActivityAdmissionAfterStartup()`
  calls.

---

### M-3 — Core types referenced in committed source are defined only in uncommitted `WealthCore.swift`

**Files affected:** Multiple (see list below)  
**Types not defined in committed source:**  
`WealthMarketUniverseStore`, `WealthPortfolioStore`, `WealthAllCardsStore`, `WealthEventLogStore`,
`WealthCardHoldingRouter`, `Opportunity`, `MarketSignal`, `Holding`, `WealthMarketQualityTier`,
`WealthAILiveCoordinator` (defined in `WealthAILiveCoordinator+Evaluation.swift` — this one _is_
committed), `WealthBrokerQuote`, `EngineStateBundle`

**Committed files that reference undefined types:**

| File | Undefined type(s) used |
|------|------------------------|
| `WealthEngineStore+Activation.swift` | `WealthMarketUniverseStore` |
| `WealthEngineStore+BackgroundCache.swift` | `Opportunity`, `MarketSignal`, `Holding`, `EngineStateBundle` |
| `WealthEngineStore+Materialization.swift` | `WealthCardHoldingRouter`, `WealthAllCardsStore`, `WealthMarketQualityTier`, `Opportunity` |
| `WealthEngineStore+Recovery.swift` | `PersistenceManager` (committed), `WealthEventLogStore` |
| `WealthEngineStore+Refresh.swift` | `WealthBrainStore` (committed), `Opportunity` |
| `WealthPortfolioStore+Lifecycle.swift` | `WealthPortfolioStore`, `tradingLifecycleArmed`, `reconcileActivityAdmissions()` |
| `WealthPortfolioStore+LifecycleHelpers.swift` | `WealthPortfolioStore.shared.tradingLifecycleArmed` |
| `WealthNewComponentsBootstrap.swift` | `WealthAllCardsStore`, `WealthAILiveCoordinator.promotedCards`, `WealthEventLogStore` |
| `WealthBrainStore.swift` | `WealthIBKRBridge` (committed), `WealthEngineStore` (committed), `WealthEventLogStore` |

**What is wrong:** The committed source files form only a partial build. All actual Xcode builds
require the uncommitted `WealthCore.swift` to provide the missing type definitions. This is a
structural constraint that:

1. Makes the SPM test target the only standalone-compilable target — it avoids all of these types.
2. Prevents any CI tooling from validating the Xcode app target without access to `WealthCore.swift`.
3. Creates an invisible dependency: any rename or removal in `WealthCore.swift` silently breaks the
   committed extension files, and CI will not catch it.

**Performance and reliability impact:**
- No direct runtime impact — `WealthCore.swift` is present on developer machines.
- CI has zero ability to detect compilation failures in the 40 committed app-source files.
- Developers who clone the repo cannot build the Xcode app target without access to `WealthCore.swift`
  (which is absent from git), making the repository non-self-contained for new contributors.

---

## Low findings

### L-1 — `subscribeMarketData` does not validate `exchange` or `currency`

**File:** `Wealth Creation/WealthIBKRBridge+Send.swift`  
**Line:** 53

```swift
func subscribeMarketData(contract: WealthIBKRContract) -> Int {
    guard !contract.symbol.trimmingCharacters(in: .whitespaces).isEmpty else { ... return -1 }
    guard !contract.secType.trimmingCharacters(in: .whitespaces).isEmpty else { ... return -1 }
    // exchange and currency are NOT validated
    let reqID = nextReqID()
    send([...  contract.exchange,  ...  contract.currency,  ...])
}
```

**What is wrong:** `symbol` and `secType` are validated before sending, but `exchange` and
`currency` are sent to TWS without validation. An empty `exchange` string causes TWS to silently
route the subscription through a default exchange, which may return incorrect prices. An empty
`currency` causes TWS to use a default currency that may not match the intended instrument.

**Impact:** Low — TWS will reject or misroute the request rather than producing a silent data
corruption, but the omission is inconsistent with the validation intent of the surrounding code.

---

### L-2 — NWListener init failure in `WealthPeerSyncService` logs only to OSLog, not to `WealthEventLogStore`

**File:** `Wealth Creation/WealthPeerSyncService.swift`  
**Line:** 82

```swift
guard let l = try? NWListener(using: .tcp) else {
    log.error("PeerSync: NWListener init failed")   // OSLog only
    return
}
```

**What is wrong:** All other components that encounter errors record them to `WealthEventLogStore`
so they are visible in the app's in-app event log. Peer sync failures only write to the system
OSLog, which is not visible to the user or to any in-app diagnostic screen.

**Impact:** Low — the error is still recorded (in the console). It makes peer-sync failures harder
to diagnose without a device attached to Xcode.

---

### L-3 — Timer callbacks create an inner `Task` with no tracked handle

**File:** `Wealth Creation/WealthEngineStore+Timers.swift`  
**Lines:** 96–107 (makeIBKRTimer), 109–120 (makeSoftTimer), 122–133 (makeDeepTimer)

```swift
Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
    guard let self else { return }
    Task { @MainActor [weak self] in        // ← no handle stored
        guard let self else { return }
        self.activationStage = stage
        Task.detached(priority: .userInitiated) { [weak self] in   // ← no handle stored
            await self?.refresh(mode: .ibkr)
        }
    }
}
```

**What is wrong:** Each timer callback creates an unstructured `Task` (and a nested `Task.detached`)
with no stored handle. Neither task can be cancelled externally; they run to completion regardless
of any timer invalidation that occurs concurrently.

If `invalidateTimers()` is called while a timer callback's inner `Task` is already in flight, the
task will continue executing and calling `refresh(mode:)` after the timer has been removed and
`rescheduleTimers()` has started. This could result in a stale refresh running concurrently with
the next scheduled refresh.

**Impact:** Low in practice — the tasks are short-lived and the `[weak self]` guards exit quickly
if `self` is gone. However, it means timer teardown is not truly atomic: there is a brief window
where old-timer refresh work can overlap with new-timer refresh work.

---

### L-4 — `WealthTimerHolder` has mutable state under `nonisolated(unsafe)`

**File:** `Wealth Creation/WealthEngineStore+Timers.swift`  
**Line:** 31

```swift
private final class WealthTimerHolder {
    var ibkrTimers: [Timer] = []
    var extraSoftTimers: [Timer] = []
}

private nonisolated(unsafe) let timerHolder = WealthTimerHolder()
```

**What is wrong:** `WealthTimerHolder` is a reference-type class with two mutable `[Timer]` arrays.
It is accessed in `invalidateTimers()`, `scheduleRecurringTimers()`, and the timer callback closures.
`nonisolated(unsafe)` suppresses the Swift concurrency check that would otherwise require `timerHolder`
to be accessed only from `@MainActor`.

This is safe today only because all access paths happen to run on the main thread. If a future
refactor moves `rescheduleTimers()` inside a `Task.detached`, or if an editor adds an `@concurrent`
call that touches `timerHolder`, there will be no compile-time warning.

**Impact:** Low — the current code paths are all main-thread. The risk is future-code fragility.

---

### L-5 — No test coverage for the materialization pipeline or safeguard gate

**File:** `Tests/AWCTests/AWCTests.swift`

**What is wrong:** The test suite covers timer scheduling (`WealthEngineTimerTests`), async object
lifetime (`MarketDataFetcherLifetimeTests`), persistence atomicity (`PersistenceManagerAtomicityTests`),
secret-config parsing (`AWCSecretConfigTests`), and error descriptions (`FetchErrorDescriptionTests`).

The following areas have no test coverage at all:

| Untested area | Risk |
|---------------|------|
| `evaluateSafeguards(for:)` in `WealthEngineStore+Materialization` | Placeholder earningsRisk/macroRisk produce wrong rejections (C-2) |
| `materializeMarketCandidates()` | Dead `ranked` assignment (C-1) goes undetected by tests |
| `Opportunity+CardStateMachine` (earningsRisk, macroRisk, isStrongGreen, isWeakGreen) | Safeguard gate decisions are untested |
| `WealthBrainStore.ingest()` | No verification that learn()/bias() are called |
| `WealthDownstreamRebuildOrchestrator.triggerRebuild()` | Re-entrancy guard untested |
| `WealthReadyStateGate.markDownstreamRebuildComplete()` | Notification posting untested |

**Impact:** Low for test infrastructure in isolation, but high in combination with C-1 and C-2:
because these paths are untested, the dead-assignment bug (C-1) and wrong safeguard decisions (C-2)
are invisible to automated validation and can only be caught by manual testing.

---

## Informational notes

### I-1 — CI swift test passes cleanly (30/30 tests pass)

The SPM test target compiles and all 30 tests pass on Linux / Swift 5.9. This is the only
automated validation currently available. See H-4 for why this does not validate the Xcode app
target.

### I-2 — `WealthPeerSyncService` callbacks correctly wrap their handlers in `Task { @MainActor ... }`

Despite the `queue: .main` delivery issue (H-3), the `browseResultsChangedHandler` and
`listenerDidChangeState` closures both wrap their work in `Task { @MainActor in ... }` as intended.
Once H-3 is addressed (changing `queue: .main` to a private background queue), these closures
require no changes.

### I-3 — Atomic persistence (Issue 6) and secret management (Issue 8) are correctly implemented

`PersistenceManager.saveBundle(_:)` uses `.atomic` write options. `AWCSecretConfig` reads from
`Documents/awc.env` and falls back to built-in defaults with no hardcoded secrets in source.
Both implementations are sound.

### I-4 — `WealthIBKRBridge.connect()` correctly validates host and port before connecting

Added in Issue 9: empty-host and zero-port guards prevent a silent NWConnection start failure.
The validation is well-placed and the error path emits a user-visible `.failed` event.

### I-5 — `WealthEngineRuntimeRecovery` and `WealthEngineRuntimeCoordinator` are correctly implemented

Both components use debounce guards and `@MainActor` isolation correctly. No issues were found.

### I-6 — `WealthDownstreamCacheSanity` freshness thresholds match the deep-refresh timer (30 min)

The 30-minute background threshold in `WealthStaleCacheDetector` matches the deep-refresh timer
interval, so a cache is only considered stale after a full timer cycle would have refreshed it.
This is appropriate.

---

*End of audit report. No code changes were made. This document is a findings-only report.*
