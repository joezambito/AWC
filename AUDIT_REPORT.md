# joezambito/AWC — Comprehensive Audit Report

**Date:** 2026-04-05  
**Scope:** All 33 Swift source files in `Wealth Creation/` + DerivedData build-artifact analysis  
**Format:** Final draft — diagnosis only, no code changes  

---

## Table of Contents

1. [Critical Bugs & Errors](#1-critical-bugs--errors)
2. [Code Quality & Style Issues](#2-code-quality--style-issues)
3. [Security & Vulnerability Findings](#3-security--vulnerability-findings)
4. [Dependency Health & Status](#4-dependency-health--status)
5. [CI/CD Configuration & Status](#5-cicd-configuration--status)
6. [Test Coverage & Gaps](#6-test-coverage--gaps)
7. [Documentation Completeness](#7-documentation-completeness)
8. [Performance Bottlenecks](#8-performance-bottlenecks)

---

## 1. Critical Bugs & Errors

---

### 1.1 Placeholder Risk Calculations Drive Live Trading Decisions

**File:** `Wealth Creation/Opportunity+CardStateMachine.swift`  
**Lines:** 65–88  
**Properties:** `earningsRisk`, `macroRisk`

Both properties use admitted placeholder math and are explicitly marked with `⚠️ PLACEHOLDER` warnings in the source code:

- `earningsRisk` is derived from the generic `risk` float (0–1 → 0–100), which is **not** earnings-specific.
- `macroRisk` is derived from `1.0 - probability`, which is **not** macro/geopolitical risk.

**Impact:** The safeguard gate in `WealthEngineStore+Materialization.swift` uses these values (`earningsRisk ≥ 70` and `macroRisk ≥ 75`) to gate which cards enter Market ranking, and `WealthAILiveRejectionAudit` reports on them as if they were accurate. The source comments acknowledge: *"WILL produce incorrect safeguard decisions in production until replaced."* Cards that should be blocked may pass, and safe cards may be incorrectly blocked — directly affecting which trades can reach Activity.

---

### 1.2 Ranked Cards Never Written Back to `rankedAssets` After Materialization

**File:** `Wealth Creation/WealthEngineStore+Materialization.swift`  
**Function:** `materializeMarketCandidates()`  
**Lines:** 81–102

The result of `assignMarketRanks(to:)` is stored in local `let ranked = ...` but **never assigned** to `rankedAssets` or any other stored property. Only `WealthAllCardsStore.shared.sync(opportunities: rankedAssets, ...)` is called — using the **pre-ranking** `rankedAssets`. The ranked output is silently discarded.

**Impact:** No card in the system ever has a non-zero rank (all `rank == 0`) after materialization completes. Every downstream check that depends on `card.rank > 0` (AI Live evaluation filtering, market snapshot persistence, order restriction audit) operates on zero-rank cards, producing empty results throughout the entire pipeline.

---

### 1.3 Duplicate and Conflicting Startup Paths

**Files:** `Wealth Creation/WealthEngineStore+Activation.swift`, `Wealth Creation/WealthEngineStore+Bootstrap.swift`, `Wealth Creation/WealthEngineStartupController.swift`  
**Functions:** `runActivationSequence()`, `bootstrap()` → `WealthAppSessionController.prepareLaunch()` → `WealthEngineStartupController.beginStartupSequence()`

Two entirely separate startup pipelines exist and can both be triggered:

- **Path A:** `runActivationSequence()` manages its own `activationTask`, cancels `scheduledCheckpointTimer`/`preScanBurstTimer` (legacy timer properties), calls `WealthMarketUniverseStore` directly, then sets `tradingLifecycleArmed`, `activationCycleComplete`, and calls `rescheduleTimers()`.
- **Path B:** `bootstrap()` → `prepareLaunch()` → `beginStartupSequence()` uses a completely separate `WealthEngineStartupController`, its own `startupTask`, lifecycle events, and `WealthEngineScanScheduler` progress tracking.

Neither path calls the other. The `invalidateTimers()` function invalidates `softTimer` and `heavyTimer` but not `scheduledCheckpointTimer` or `preScanBurstTimer`, which are managed only by Path A.

**Impact:** Running both paths on a single launch starts two concurrent background sequences: two sets of universe scans, two AI passes, and two calls to `rescheduleTimers()`. This results in duplicate timer sets (up to 12 timers instead of 6), duplicate scan work, and conflicting state writes to the same `@Published` properties.

---

### 1.4 `endDashboardRefreshFreeze()` Called but Never Defined in Committed Code

**File:** `Wealth Creation/WealthEngineStore+Activation.swift`  
**Line:** 61 (inside `defer` block)

`endDashboardRefreshFreeze()` is called on cancellation path inside `runActivationSequence()`. This function does not exist in any of the 33 committed source files. It exists only in `WealthCore.swift`, which is **not committed to the repository**.

**Impact:** If `runActivationSequence()` is ever cancelled, the project will fail to compile unless `WealthCore.swift` is present. The repository does not represent a fully buildable state.

---

### 1.5 `reconcileActivityAdmissions()` Called but Never Defined in Committed Code

**File:** `Wealth Creation/WealthPortfolioStore+Lifecycle.swift`  
**Line:** 53

`reconcileActivityAdmissions()` is called inside `rerunActivityAdmissionAfterStartup()`. This function is not present in any committed source file.

**Impact:** Activity admission re-run after startup (Blocker #6 fix) silently fails to compile without `WealthCore.swift`. The post-startup Activity reconciliation the architecture depends on cannot execute.

---

### 1.6 `runStartupActivationScan()` and `runStartupMarketWarmup()` Not Defined in Committed Code

**File:** `Wealth Creation/WealthEngineStore+Activation.swift`  
**Lines:** 89, 93

Both functions are `await`-called inside the detached background task of `runActivationSequence()` but are defined only in `WealthCore.swift` (not in git).

**Impact:** Same buildability issue as 1.4 and 1.5. The startup Path A (activation sequence) cannot compile without the un-committed core file.

---

### 1.7 `WealthBrainStore.learn()` and `WealthBrainStore.bias()` Are Empty Stubs

**File:** `Wealth Creation/WealthBrainStore.swift`  
**Lines:** 71–79

Both methods contain only comments stating implementations live in `WealthCore.swift`. `learn()` is called on every `ingest()` pass (every soft and deep timer refresh), but does nothing.

**Impact:** The AI brain never accumulates learning from scan cycles. Every `performAIScan()` call records a "Brain Ingest" event log entry and returns, but no scoring bias is ever applied. The `bias()` function is never called anywhere in the committed code and has no call site.

---

### 1.8 `performResearchFeeds()` and `performIBKRSync()` Are Empty Stubs

**File:** `Wealth Creation/WealthEngineStore+Refresh.swift`  
**Lines:** 126–130

Both `@MainActor` methods have empty bodies with a comment pointing to `WealthCore.swift`.

**Impact:** The deep refresh (30-minute timer) calls `runResearchFeeds()` → `performResearchFeeds()` which does nothing. IBKR price-only sync (9m/19m/29m timers) calls `runIBKRPriceSync()` → `performIBKRSync()` which does nothing. All IBKR price updates and research feed data are silently skipped every cycle.

---

### 1.9 `performUniverseScan()` Is an Empty Stub

**File:** `Wealth Creation/WealthEngineStore+Refresh.swift`  
**Lines:** 103–108

`performUniverseScan()` is marked `@MainActor` with an empty body. It is the call terminus for every universe scan in the pipeline (startup + timers).

**Impact:** The entire universe scan pipeline terminates with no work done at the call site. All 128k card population depends on logic in `WealthCore.swift` that is not committed, meaning the pipeline only functions when the un-versioned file is present.

---

### 1.10 `WealthIBKRBridge.handleApiMessage(data:)` Is an Empty Stub

**File:** `Wealth Creation/WealthIBKRBridge.swift`  
**Line:** 174

After handshake completion, all incoming TWS API messages (market data ticks, account updates, order confirmations) are received, length-prefixed, extracted, and then passed to `handleApiMessage(data:)` which does nothing.

**Impact:** IBKR connection is established (the handshake is complete), but zero market data, quotes, positions, or order status updates are ever processed. The broker bridge is architecturally wired but functionally deaf after connection.

---

### 1.11 `downstreamRecoveryPending` Set but Never Cleared in Committed Code

**File:** `Wealth Creation/WealthEngineStore+Activation.swift`  
**Line:** 52

`downstreamRecoveryPending = true` is set at the start of `runActivationSequence()`. There is no `downstreamRecoveryPending = false` assignment in any of the 33 committed source files.

**Impact:** Any conditional logic gated on `downstreamRecoveryPending == false` will never be satisfied after the first activation. The flag is stuck permanently `true` unless the clearing assignment is in `WealthCore.swift`.

---

### 1.12 `nonisolated(unsafe)` Timer Holder Bypasses Swift Concurrency Checks

**File:** `Wealth Creation/WealthEngineStore+Timers.swift`  
**Line:** 31

```swift
private nonisolated(unsafe) let timerHolder = WealthTimerHolder()
```

`nonisolated(unsafe)` opts out of Swift's actor isolation checking. The comment asserts MainActor access is always serialized, but the Swift compiler cannot verify this. A future refactor that accesses `timerHolder` from a non-MainActor context (e.g., a `Task.detached` block) would introduce a data race with no compile-time warning.

**Impact:** Silent data races on timer array mutation, leading to duplicate or missing timer entries, incorrect timer counts, and missed scan cycles.

---

## 2. Code Quality & Style Issues

---

### 2.1 Core Source Files Not Committed — Repository Is Not Buildable

**DerivedData evidence:** `WealthCore.SwiftFileList` lists  
`WealthCore.swift`, `ContentView.swift`, `WealthPanelsAndDetails.swift`, `WealthScreens.swift`, `WealthSystemAndDetailViews.swift`, `WealthUIComponents.swift`, `Wealth_CreationApp.swift`

None of these 7 files are in git. The 33 committed extension files reference dozens of types and functions (`WealthPortfolioStore`, `WealthAllCardsStore`, `WealthEventLogStore`, `WealthMarketUniverseStore`, `WealthCardHoldingRouter`, `WealthResearchFeedEngine`, `WealthMarketQualityTier`, `MarketUniverseRecord`, `MarketSignal`, `Holding`, `Opportunity`, `WealthEngineStore` class definition, etc.) that exist only in the un-committed files.

**Impact:** `git clone` + `xcodebuild` produces compiler errors. The repository is a partial snapshot, not a standalone project. Collaboration, code review, CI, and audit are all hampered.

---

### 2.2 Class Definition Inside Extension File

**File:** `Wealth Creation/WealthAILiveCoordinator+Evaluation.swift`  
**Lines:** 1–22

The `WealthAILiveCoordinator` class itself (with `shared`, `promotedCards`, `lastEvaluationDate`) is declared at the top of a `+Evaluation` extension file rather than in a dedicated base file. Swift allows this, but convention and project consistency require a base type file.

**Impact:** Navigation tools (Xcode quick-open, "Jump to Definition") may struggle to find the type's stored property declarations. Future contributors will not find the type where expected.

---

### 2.3 Widespread Silent Error Swallowing in Cache I/O

**Files:** `Wealth Creation/WealthEngineStore+Cache.swift` (L101–141), `Wealth Creation/WealthEngineStore+BackgroundCache.swift` (L62–133)  
All file reads, JSON decodes, JSON encodes, and file writes use `try?` with no error logging.

`WealthDownstreamCacheSanity.persistToFile()` does log errors correctly, but the main engine cache files do not.

**Impact:** When a file write fails (disk full, permissions error, sandbox violation), the caller receives no indication. Cache silently becomes stale or absent, leading to empty UI on next launch with no diagnostic trail.

---

### 2.4 `save()` Performs Main-Thread JSON Encoding

**File:** `Wealth Creation/WealthEngineStore+Cache.swift`  
**Function:** `save()`  
**Lines:** 81–93

`save()` calls `persistRankedAssetsToFile()`, `persistScannedSignalsToFile()`, and `persistHoldingsToFile()` synchronously. It is called from `applicationWillTerminate()` in `WealthAppSessionController` on the main thread. Encoding 128k+ cards synchronously blocks the main thread until complete.

**Impact:** Application termination can cause a multi-second UI freeze; on iOS, the OS will kill the app if it doesn't return from `applicationWillTerminate` quickly enough, potentially truncating the write.

---

### 2.5 Polling Loop for `tradingLifecycleArmed` with Silent Failure

**File:** `Wealth Creation/WealthPortfolioStore+LifecycleHelpers.swift`  
**Function:** `scheduleArmedRetry(attemptsRemaining:)`  
**Lines:** 71–92

Polls once per second for up to 30 seconds. If `tradingLifecycleArmed` never becomes `true`, the function logs "gave up" and returns without triggering any fallback recovery.

**Impact:** If the activation sequence is disrupted, Activity reconciliation silently never runs. The 30-second task also holds a strong reference to `WealthPortfolioLifecycleHelper` through its closure chain.

---

### 2.6 MARK Comment Broken by Same-Line Code

**File:** `Wealth Creation/WealthStaleCacheDetector.swift`  
**Lines:** 69–70

```swift
let backgroundFreshnessThreshold: TimeInterval = 30 * 60    // MARK: - Public API
```

The `// MARK:` is appended to an existing code line rather than on its own line. Xcode's source navigator does not display this MARK separator, breaking the intended code organization.

---

### 2.7 Circular Bootstrap Call Chain

**File:** `Wealth Creation/WealthNewComponentsBootstrap.swift`  
**Function:** `bootstrapWithPipeline()`  
**Lines:** 117–127

`bootstrapWithPipeline()` calls `bootstrap()`, which calls `WealthAppSessionController.prepareLaunch()`, which calls `WealthNewComponentsBootstrap.activate()`. The comment acknowledges this circular path and states `activate()` is a no-op due to the `isActivated` guard. While functionally safe due to guards, the call chain is confusing and fragile if the guards are ever changed.

---

### 2.8 `WealthEngineStore+Activation.swift` References Superseded Timer Properties

**File:** `Wealth Creation/WealthEngineStore+Activation.swift`  
**Lines:** 43–50

Invalidates `scheduledCheckpointTimer` and `preScanBurstTimer` — properties documented in memory as **removed** from the current architecture (timer architecture memory: *"softTimer, heavyTimer, and preScanBurstTimer were removed"*). The current timer system only uses `softTimer` and `heavyTimer` (plus the holder). Nulling non-existent properties is harmless in Swift but indicates a divergence between the activation logic and the current timer architecture.

---

### 2.9 `WealthEngineScanScheduler.reset()` Not Called Between Cycles

**File:** `Wealth Creation/WealthEngineScanScheduler.swift`  
**Function:** `reset()`  
**Lines:** 98–101

`reset()` exists but is never called between recurring 30-minute cycles (it's only called during factory reset in `WealthEngineRuntimeRecovery`). After the first startup cycle completes, `completedPhases` remains fully populated and `currentProgress` stays at `1.0`. Subsequent calls to `markPhaseComplete(_:)` are all no-ops (duplicate guard). Scan progress never reflects the state of recurring timer cycles.

**Impact:** `hasReachedAILiveGate` is permanently `true` after startup, which is the intended behavior, but the progress metric has no meaning for recurring cycles and cannot detect a stalled mid-cycle state.

---

## 3. Security & Vulnerability Findings

---

### 3.1 GPG Public Key Committed at Repository Root

**File:** `gpg_key.txt`  
**Location:** Repository root

A PGP public key block is committed directly in the repository. While a public key is not cryptographically sensitive, committing key material to source control:
- Triggers false positives in automated secret-scanning tools (e.g., GitHub Advanced Security, truffleHog).
- Sets a precedent that key material belongs in the repository (which becomes dangerous if a private key is later committed by mistake).
- Has no operational purpose that could not be served by a keyserver upload.

**Impact:** Medium. Not a secret leak, but a security hygiene violation.

---

### 3.2 Hardcoded Internal IP Address in Production Code

**File:** `Wealth Creation/WealthIBKRBridge+Send.swift`  
**Line:** 169

```swift
"IBKRBridge diagnosis: connection timed out — check LAN route to TWS host (192.168.1.21)"
```

A specific internal LAN IP address (`192.168.1.21`) is hardcoded in a diagnostic log message that will appear in production log streams (uses `OSLog.error`).

**Impact:** Reveals internal network topology in production logs. If logs are collected by a third-party service (Crashlytics, DataDog, etc.), this internal IP is exposed outside the organization. Should be a configurable constant, not a hardcoded literal.

---

### 3.3 IBKR Broker Connection Has No TLS / Authentication

**File:** `Wealth Creation/WealthIBKRBridge.swift`  
**Lines:** 88–100 (`connect(host:port:)`)

The connection to Interactive Brokers TWS uses plain TCP (`NWConnection` with `.tcp` parameters and no TLS options). No certificate pinning, no mutual authentication, and no encryption layer.

**Impact:** All financial data transmitted between the app and TWS (market quotes, account balances, order confirmations) is transmitted in plaintext on the local network. A man-in-the-middle attack on the LAN could intercept or inject broker messages. Financial application broker connections must use encrypted, authenticated channels.

---

### 3.4 Financial Data Files Have No Data Protection Class

**Files:** `Wealth Creation/WealthEngineStore+Cache.swift`, `Wealth Creation/WealthEngineStore+BackgroundCache.swift`, `Wealth Creation/WealthDownstreamCacheSanity.swift`

All cache files (ranked assets, AI live results, market snapshots, activity state, holdings) are written to `FileManager.urls(for: .cachesDirectory)` using `data.write(to: url, options: [.atomic])` — the `.atomic` option ensures write integrity but does **not** set a data protection class.

Default protection for files written without explicit `.completeFileProtection` is `.none` (or `.completeUntilFirstUnlock` depending on entitlements), meaning these files are readable while the device is locked.

**Impact:** On a jailbroken device, or if another process with elevated privileges accesses the Caches directory, financial data (holdings, ranked assets, AI scores, activity admissions) is readable at rest. Apple's recommendation for sensitive financial data is `.completeFileProtection`.

---

### 3.5 No Input Validation on Incoming IBKR API Messages

**File:** `Wealth Creation/WealthIBKRBridge.swift`  
**Function:** `handleApiMessage(data:)`  
**Line:** 174

After handshake, the receive loop delivers length-prefixed messages to `handleApiMessage(data:)`, which is an empty stub. When implemented, there is no validation framework, no message-type allow-list, and no length sanity check beyond the framing check in `validateMessageFrame(_:)`.

**Impact:** A malicious or malfunctioning TWS server could send arbitrarily-sized or malformed messages. Without input validation, these will be parsed by whatever future parsing logic is added, potentially causing out-of-bounds reads, incorrect balance/position values, or order injection.

---

### 3.6 `NotificationCenter` Used for Financial Pipeline Orchestration Without Authentication

**Files:** Multiple — `WealthDownstreamCacheSanity.swift`, `WealthPortfolioStore+LifecycleHelpers.swift`, `WealthNewComponentsBootstrap.swift`, `WealthEngineRefresh+LifecyclePublishing.swift`

`NotificationCenter.default` is used to orchestrate critical pipeline events (`wealthEngineDidBecomeReady`, `wealthScanProgressDidUpdate`, `wealthRefreshPhaseWillBegin`, `wealthRefreshPhaseDidComplete`). `NotificationCenter.default` is process-wide and can be posted to by any code running in the process (e.g., injected by a Tweak on jailbroken devices, or via a compromised dependency).

**Impact:** Low in a non-jailbroken production context; medium for an enterprise/sideloaded deployment. Malicious code could post `wealthEngineDidBecomeReady` prematurely, triggering the post-ready pipeline (audits, AI live evaluation, Activity admission) before legitimate data is present.

---

## 4. Dependency Health & Status

---

### 4.1 No Third-Party Dependency Manager Found

**Evidence:** No `Package.swift`, `Podfile`, `Cartfile`, `Podfile.lock`, or `Package.resolved` in the repository.

The project uses only Apple system frameworks:
- `Foundation`
- `Network`
- `OSLog`
- `SwiftUI` (referenced in DerivedData)
- `UIKit` (referenced in DerivedData module cache)
- `UserNotifications` (referenced in DerivedData module cache)

**Assessment:** Zero third-party supply-chain risk. All framework updates are controlled by Apple SDK releases. No vulnerable packages to report.

---

### 4.2 No Explicit SDK or Swift Version Pinning

**Evidence:** No `.xcode-version`, no `SWIFT_VERSION` in any committed file. Xcode project file (`*.xcodeproj`) is not in the repository.

The minimum deployment target and Swift language version are known only from DerivedData artifacts (build settings), which are not version-controlled.

**Impact:** Different team members building with different Xcode versions may produce different behavior. Swift concurrency semantics, actor isolation rules, and `@MainActor` behavior have changed across Swift 5.x minor versions. Without pinning, builds are non-reproducible.

---

## 5. CI/CD Configuration & Status

---

### 5.1 No CI/CD Configuration Exists

**Evidence:** No `.github/` directory. No GitHub Actions workflows, no branch protection rules, no status checks.

**Current state:** All integration, testing, and deployment is entirely manual.

**Gaps identified:**

| Gap | Risk |
|-----|------|
| No automated build | Broken builds can be merged to main undetected |
| No automated test run | Regressions ship without detection |
| No linting / SwiftLint gate | Code style violations accumulate |
| No Swift concurrency analysis | Data races introduced silently |
| No secret scanning | Accidental credential commits undetected |
| No PR size / review gate | Large un-reviewed changes merge freely |
| No deployment automation | Manual deploy steps introduce human error |

---

### 5.2 Build Artifacts Committed to Repository

**Directory:** `DerivedDataLocalMac/` (entire Xcode DerivedData tree)

Xcode's `DerivedData` folder (compilation caches, `.o` object files, `.swiftdeps` dependency graphs, module caches) is committed to the repository and tracked by git. This directory should be in `.gitignore`.

**Impact:**
- Repository size inflated by binary build artifacts.
- Stale build artifacts may cause incorrect behavior if checked out on a machine with a different Xcode/SDK version.
- Sensitive build path information is exposed (`/Users/joezambito/LocalProjects/Wealth Creation/...`).

---

### 5.3 No `.gitignore` for Standard Xcode Exclusions

**Evidence:** No `.gitignore` file found in the repository root.

Standard exclusions for an Xcode project (`.DS_Store`, `DerivedData/`, `*.xcuserstate`, `*.xcbkptlist`, build output directories) are all absent from gitignore.

**Impact:** `.DS_Store` files and `DerivedDataLocalMac/` are being tracked. Future contributors will pollute git history with their own derived data artifacts.

---

## 6. Test Coverage & Gaps

---

### 6.1 Zero Test Files in Repository

**Evidence:** No `*Tests.swift`, `*Spec.swift`, or `XCTestCase` subclass files found anywhere in the repository. DerivedData shows no test target build artifacts.

**Current test coverage: 0%**

---

### 6.2 Critical Financial Logic Completely Untested

The following logic paths handle or influence real trading decisions and have no test coverage:

| Component | File | Risk |
|-----------|------|------|
| `earningsRisk` / `macroRisk` placeholder calculations | `Opportunity+CardStateMachine.swift` L65–88 | Safeguard gate incorrect → wrong cards traded |
| Safeguard gate (`evaluateSafeguards(for:)`) | `WealthEngineStore+Materialization.swift` L113–133 | Cards that should be blocked enter market |
| Market rank assignment (dense rank logic) | `WealthEngineStore+Materialization.swift` L147–162 | Incorrect rank → wrong Activity queue ordering |
| Startup sequence phase ordering | `WealthEngineStartupController.swift` | Wrong sequence → empty UI / stale data |
| Stale cache detection thresholds | `WealthStaleCacheDetector.swift` | Stale data treated as live |
| Session resume / rebuild trigger | `WealthSessionUnlockController.swift`, `WealthEngineRuntimeCoordinator.swift` | Session reopens without data refresh |
| IBKR handshake framing | `WealthIBKRBridge.swift` | Broker disconnects, no prices |
| Cache file write/read round-trip | `WealthEngineStore+Cache.swift` | Silent data loss on restart |

---

### 6.3 Audit Reports Self-Report but Are Never Validated

**Files:** `WealthMarketExecutionAudit.swift`, `WealthAILiveRejectionAudit.swift`, `WealthActivityAdmissionAudit.swift`, `WealthOrderRestrictionRules.swift`

All four audit classes produce structured reports (`lastReport` stored property) but no test ever validates that the counts are correct for known inputs. If the underlying property (e.g., `isMarketExecutableCandidate`) changes behavior, the audits will silently report incorrect counts.

---

### 6.4 No Integration or UI Tests

There are no integration tests validating end-to-end flows (startup → universe load → market ranking → AI live → Activity), and no UI/snapshot tests confirming that the SwiftUI dashboard renders correctly under various engine states (loading, empty, error, populated).

---

## 7. Documentation Completeness

---

### 7.1 No README.md

The repository has no README file of any kind. A first-time visitor or collaborator has no entry point explaining:
- What the app does
- How to build and run it
- Architecture overview
- Required configuration (TWS host, port, client ID)
- Known limitations or in-progress work

---

### 7.2 Core Types Undefined in Repository

The following types are referenced throughout all 33 committed files but are never defined in git:

| Type | Used In |
|------|---------|
| `WealthEngineStore` (class definition) | All extension files |
| `Opportunity` | All pipeline files |
| `MarketSignal` | Cache, refresh files |
| `Holding` | Cache, portfolio files |
| `WealthPortfolioStore` | Lifecycle files |
| `WealthAllCardsStore` | Materialization, bootstrap |
| `WealthEventLogStore` | All audit files |
| `WealthMarketUniverseStore` | Activation, blueprints |
| `WealthCardHoldingRouter` | Materialization |
| `MarketUniverseRecord` | Blueprints |
| `WealthMarketQualityTier` | Materialization |
| `WealthAILiveCoordinator` (base) | Bootstrap |

Any documentation, API reference, or architecture diagram that describes these types does not exist in the repository.

---

### 7.3 Unresolved "Once Core Is Refactored" Migration Notes

**Files:**
- `Wealth Creation/WealthEngineStore+Recovery.swift` L47–49
- `Wealth Creation/WealthBrainStore.swift` L66
- `Wealth Creation/WealthEngineStore+Refresh.swift` L105

Multiple files contain migration instructions such as *"Once the core file is refactored, remove the original stub and keep only this implementation."* There is no tracking issue, no timeline, no owner, and no definition of "done" for these migrations.

**Impact:** These notes represent technical debt that accumulates. Without a tracking mechanism, the migration never happens and the stubs coexist with implementations indefinitely.

---

### 7.4 No Architecture Diagram

The system has a complex multi-stage pipeline (Universe → AI → Market → AI Live → Activity) with 11+ singleton orchestrators coordinating via NotificationCenter, stored tasks, and direct method calls. No diagram, sequence chart, or architecture document exists to show how these components relate or in what order they execute.

---

### 7.5 No CHANGELOG or Versioning History

No `CHANGELOG.md`, `RELEASES.md`, or semantic versioning documentation. The only history is git commits, and the repository history is a shallow clone (only 2 commits visible). There is no record of what changed between releases.

---

## 8. Performance Bottlenecks

---

### 8.1 `save()` Encodes 128k Cards Synchronously on Main Thread

**File:** `Wealth Creation/WealthEngineStore+Cache.swift`  
**Function:** `save()`  
**Called from:** `WealthAppSessionController.applicationWillTerminate()` (main thread)

`save()` encodes and writes three large JSON arrays synchronously. At 128k cards, the JSON encode alone takes multiple seconds on an iPhone-class device.

**Impact:** App may be force-killed by the OS during the encode before the write completes, resulting in data loss. The UI is frozen for the duration.

---

### 8.2 Fixed Startup Delays Add Minimum 4-Second Latency

**File:** `Wealth Creation/WealthEngineStartupController.swift`  
**Lines:** 83, 90, 97  
**Delays:** 2s after universe, 1s after AI, 1s after market

These `Task.sleep` calls are hard-coded regardless of device speed, network conditions, or actual data readiness.

**Impact:** On fast devices with warm caches, the startup sequence takes at least 4 seconds to deliver live ranked data regardless of how quickly each phase actually completes. There is no adaptive or event-driven mechanism to proceed as soon as each phase finishes.

---

### 8.3 30-Second Polling Task for `tradingLifecycleArmed`

**File:** `Wealth Creation/WealthPortfolioStore+LifecycleHelpers.swift`  
**Function:** `scheduleArmedRetry(attemptsRemaining:)`  
**Maximum duration:** 30 seconds (1 poll/second × 30 attempts)

On every startup, a recursive polling task runs on the main actor for up to 30 seconds. Each iteration schedules a 1-second sleep and then dispatches back to the main actor.

**Impact:** 30 one-second main-actor wake-ups per startup. On slow devices, this contributes to UI scheduling jitter. It also holds a retained reference to `WealthPortfolioLifecycleHelper.shared` for up to 30 seconds per startup.

---

### 8.4 Synchronous File Attribute Reads on Main Actor

**File:** `Wealth Creation/WealthDownstreamCacheSanity.swift`  
**Function:** `isFileFresh(at:)`  
**Lines:** 228–232

`FileManager.attributesOfItem(atPath:)` is a synchronous filesystem call. It is called from `isAILiveResultsFresh`, `isMarketSnapshotFresh`, and `isActivityStateFresh`, all of which are called from `validatePersistedDownstreamState()` on the `@MainActor`.

**Impact:** On devices with slow or heavily-loaded storage (rare but possible), filesystem attribute reads stall the main actor. Three synchronous reads on every engine-ready notification.

---

### 8.5 Excessive NotificationCenter Traffic per Scan Cycle

**File:** `Wealth Creation/WealthEngineRefresh+LifecyclePublishing.swift`

Each scan phase posts 2 notifications (willBegin + didComplete). With 4 phases per cycle, each 30-minute deep cycle generates 8 NotificationCenter posts. All observers receive and process these on the main thread.

With 6 timer events per 30-minute window (3 IBKR + 2 soft + 1 deep):
- IBKR sync (3×): no lifecycle publishing wrappers (uses raw `refresh(mode: .ibkr)`)
- Soft refresh (2×): `runUniverseScanWithProgress()` + `runAIScanWithProgress()` + `runMarketRankingWithProgress()` = 6 notifications each = **12 notifications**
- Deep refresh (1×): 8 notifications

**Total:** ~20+ NotificationCenter posts per 30-minute window, in addition to scan scheduler posts and any downstream observers.

---

### 8.6 `WealthDownstreamRebuildOrchestrator` Does Not Deduplicate Rebuild Triggers

**File:** `Wealth Creation/WealthDownstreamRebuildOrchestrator.swift`  
**Function:** `triggerRebuild(reason:)`  
**Lines:** 52–70

The in-flight deduplication only prevents a second rebuild from starting while one is running. If `triggerRebuild` is called while no rebuild is in flight (e.g., rapid background/foreground transitions that each call `checkAndRebuildIfNeeded()`), multiple sequential rebuilds are scheduled back-to-back. Each rebuild runs a full AI scan + market ranking pass.

**Impact:** On rapid unlock/lock cycles, multiple full AI + market ranking passes run consecutively, causing unnecessary CPU and memory pressure.

---

*End of Audit Report — joezambito/AWC — 2026-04-05*
