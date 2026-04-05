# 🚨 AWC Swift Codebase — Comprehensive Critical Bug & Error Audit Report

**Repository:** joezambito/AWC  
**Audit Date:** 2026-04-05  
**Files Analyzed:** 33 Swift source files in `Wealth Creation/`  
**Scope:** All critical bugs, errors, stubs, and architectural flaws — NO code changes, diagnosis only.

---

## Quick-Reference Index

| # | Severity | Theme | File | Lines |
|---|----------|-------|------|-------|
| 1 | 🔴 CRITICAL | Data Pipeline | WealthEngineStore+Refresh.swift | 103–136 |
| 2 | 🔴 CRITICAL | Data Pipeline | WealthIBKRBridge.swift | 194–196 |
| 3 | 🔴 CRITICAL | AI / Brain | WealthBrainStore.swift | 70–76 |
| 4 | 🔴 CRITICAL | Risk Scoring | Opportunity+CardStateMachine.swift | 65–98 |
| 5 | 🔴 CRITICAL | Compilation | WealthEngineStore+Activation.swift | 61 |
| 6 | 🔴 CRITICAL | Compilation | WealthEngineStore+Recovery.swift | 50–67 |
| 7 | 🔴 CRITICAL | Cache / I/O | WealthEngineStore+Cache.swift | 65–76 |
| 8 | 🔴 CRITICAL | Concurrency | WealthEngineStore+Timers.swift | 97–133 |
| 9 | 🟠 HIGH | Architecture | WealthIBKRBridge.swift | 64, 96 |
| 10 | 🟠 HIGH | Security | WealthIBKRBridge+Send.swift | 169 |
| 11 | 🟠 HIGH | Concurrency | WealthEngineStore+Activation.swift | 54 |
| 12 | 🟠 HIGH | Lifecycle | WealthPortfolioStore+LifecycleHelpers.swift | 54–91 |
| 13 | 🟡 MEDIUM | Logic | WealthEngineStore+Materialization.swift | 73–94 |
| 14 | 🟡 MEDIUM | Cache | WealthEngineStore+BackgroundCache.swift | 63–71 |
| 15 | 🟡 MEDIUM | Code Quality | WealthEngineStore+Refresh.swift | 49–66 |
| 16 | 🟡 MEDIUM | Code Quality | WealthStaleCacheDetector.swift | 46 |

---

## Theme 1 — Empty Stubs: Data Pipeline Is Non-Functional

These are the highest-severity bugs in the codebase. The core scan functions that actually deliver data to the engine are all empty stubs. The entire pipeline infrastructure (timers, orchestrators, audits, caches) runs correctly, but it operates on no real data because the I/O implementations are absent.

---

### BUG-1 🔴 CRITICAL — `performUniverseScan()`, `performResearchFeeds()`, `performIBKRSync()` Are Empty

**File:** `WealthEngineStore+Refresh.swift`  
**Lines:** 102–136  
**Functions:** `performUniverseScan()`, `performResearchFeeds()`, `performIBKRSync()`

```
102:    @MainActor
103:    func performUniverseScan() {
104:        // Implemented in WealthCore.swift (existing engine logic).
105:        // This extension stub is the designated call site; override or
106:        // extend as needed when the core implementation is refactored.
107:    }
...
128:    @MainActor
129:    func performResearchFeeds() {
130:        // Appends research-feed intel to ranked cards.
131:    }
132:
133:    @MainActor
134:    func performIBKRSync() {
135:        // Price-only sync via IBKR bridge.
136:    }
```

**Technical Impact:**
- `performUniverseScan()` is the function that downloads and scores all opportunity cards. It does nothing. Every call to `runUniverseScan()`, `runSoftRefresh()`, `runDeepRefresh()`, and `runStartupSequence()` produces zero scored cards.
- `performResearchFeeds()` is the function that attaches research intelligence to ranked cards. It does nothing. The deep refresh (every 30 minutes) never accumulates any research data.
- `performIBKRSync()` is the price-only sync called at the 9-minute, 19-minute, and 29-minute intervals. It does nothing. Live IBKR prices are never updated.
- **Net effect:** The engine starts up, runs all scan phases, respects all timers, and produces exactly zero data. The UI shows an empty or stale state on every launch.

**Root Cause:** These methods are designated call sites that are expected to be implemented in `WealthCore.swift`, which is NOT committed to the git repository. The 33 committed files are extension layer only; the actual data-fetching logic exists only in the developer's local machine.

---

### BUG-2 🔴 CRITICAL — `handleApiMessage()` Is an Empty Stub

**File:** `WealthIBKRBridge.swift`  
**Lines:** 194–196  
**Function:** `handleApiMessage(data:)`

```
194:    private func handleApiMessage(data: Data) {
195:        // Market data ticks, account updates, etc. parsed here in future extensions
196:    }
```

**Technical Impact:**
- After the IBKR TCP handshake completes and `apiReady = true`, every subsequent inbound message from TWS (price tick updates, bid/ask quotes, account balance, order status, position updates) is decoded in `processReceiveBuffer()` (line 153–163) and then passed to `handleApiMessage()` — which immediately discards it.
- The receive loop correctly parses length-prefixed frames (lines 154–163), but every successfully parsed frame goes into this empty function.
- All live broker data flowing in from TWS is silently dropped. No `WealthBrokerQuote` objects are ever created. The `subscribeMarketData()` function sends the subscription request to TWS, TWS sends back quote ticks, but the app ignores all of them.
- **Net effect:** The IBKR bridge connects successfully, subscribes to market data, but never receives or processes any of it. Live prices cannot update.

---

### BUG-3 🔴 CRITICAL — `learn()` and `bias()` in `WealthBrainStore` Are Empty Stubs

**File:** `WealthBrainStore.swift`  
**Lines:** 70–76  
**Functions:** `learn()`, `bias()`

```
70:    func learn() {
71:        // Implemented in WealthCore.swift (existing engine logic).
72:    }
73:
74:    func bias() {
75:        // Implemented in WealthCore.swift (existing engine logic).
76:    }
```

**Technical Impact:**
- `learn()` is called inside `ingest()` on every AI scan cycle (soft refresh at 10 m and 20 m, deep refresh at 30 m). It does nothing, so the brain never updates its model from observed trade outcomes.
- `bias()` is never called anywhere in the codebase at all (not in the 33 committed files). Even if implemented, it would have no call site to apply its scoring adjustments.
- `ingest()` logs a "Brain Ingest" event and calls `learn()`, giving the false appearance that the brain is functioning. All AI brain scores remain whatever they were in the last WealthCore.swift computation — they never adapt to live market cycles.
- **Net effect:** All AI adaptation is non-functional. The brain-scoring system is a log-emitting no-op.

---

## Theme 2 — Placeholder Risk Logic: Wrong Safeguard Decisions in Production

---

### BUG-4 🔴 CRITICAL — `earningsRisk` and `macroRisk` Are Explicitly Labeled Incorrect Placeholders

**File:** `Opportunity+CardStateMachine.swift`  
**Lines:** 65–98  
**Properties:** `earningsRisk`, `macroRisk`

```
65:    /// ⚠️ PLACEHOLDER – Replace this computed property with the dedicated
66:    /// earnings-risk field from the `Opportunity` model once it is available
67:    /// ...
68:    /// The current derivation from the generic `risk` float is NOT semantically
69:    /// equivalent to earnings-specific risk and WILL produce incorrect safeguard
70:    /// decisions in production until replaced.
71:    var earningsRisk: Int {
72:        // Temporary: derive from existing `risk` float property (0–1 range → 0–100).
73:        Int((risk * 100).rounded())
74:    }
75:
76:    /// ⚠️ PLACEHOLDER – Replace this computed property with a dedicated
77:    /// macro/geopolitical risk field from the `Opportunity` model.
78:    /// The current inverted-probability calculation is NOT semantically
79:    /// equivalent to macro risk and WILL produce incorrect safeguard
80:    /// decisions in production until replaced.
81:    var macroRisk: Int {
82:        // Temporary: derive from `probability` inverted (high probability → lower risk).
83:        Int(((1.0 - probability) * 100).rounded())
84:    }
```

**Technical Impact:**
- Both `earningsRisk` and `macroRisk` are consumed directly by the safeguard gate in `WealthEngineStore+Materialization.swift` (lines 114–129), which gates every card before it can enter market ranking.
- `earningsRisk` derives from the generic `risk` float field. A card with `risk = 0.72` receives `earningsRisk = 72`, triggering the ≥70 rejection — even though the card may have zero actual earnings event risk.
- `macroRisk` uses the inverse of `probability`. A card with probability = 0.10 receives `macroRisk = 90`, triggering the ≥75 rejection — but this means low-probability opportunities (which may be high-upside contrarian plays) are automatically blocked from market ranking.
- The inverted-probability macro-risk formula means that **high-probability cards receive low macroRisk** (allowed) and **low-probability cards receive high macroRisk** (blocked). Depending on how `probability` is populated, this may or may not be semantically correct — but the comments explicitly state it is NOT equivalent to macro risk.
- **Net effect:** Market ranking is making safeguard decisions based on wrong data. Cards that should pass may be rejected; cards that should be rejected may pass. The entire market preparation pipeline is operating on incorrect risk signals.

**Additional Compounding Detail:**  
`earningsRisk` and `macroRisk` are also used in `WealthAILiveRejectionAudit.swift` (lines 155–162) and `WealthAILiveCoordinator+Evaluation.swift` (lines 98–107) with the same thresholds. Any card that slips through the safeguard gate but triggers the AI Live filter based on these same incorrect fields will be rejected a second time, compounding the data quality problem.

---

## Theme 3 — Compilation Errors: Code That Will Not Build

---

### BUG-5 🔴 CRITICAL — Call to Undefined Function `endDashboardRefreshFreeze()`

**File:** `WealthEngineStore+Activation.swift`  
**Line:** 61  
**Function:** `runActivationSequence()` (defer block)

```
56:        defer {
57:            if Task.isCancelled {
58:                pendingRefreshPayload = nil
59:                startupSequencePhase = .idle
60:                endDashboardRefreshFreeze()     // ← undefined in all 33 files
61:            }
62:            activationTask = nil
63:        }
```

**Technical Impact:**
- `endDashboardRefreshFreeze()` is not defined in any of the 33 committed Swift files. The only place it could exist is in `WealthCore.swift` (not in git).
- If `WealthCore.swift` does not define this function, the project will not compile. This is a **hard build failure**.
- Even if it exists in WealthCore.swift, this represents a hidden compile-time dependency on an uncommitted file that makes the codebase non-reproducible from the committed source alone.

---

### BUG-6 🔴 CRITICAL — Duplicate `resetToFactoryDefaults()` Implementation

**File:** `WealthEngineStore+Recovery.swift`  
**Lines:** 50–67  
**Function:** `resetToFactoryDefaults()`

```
49:    /// NOTE: This method extends (replaces) the stub `resetToFactoryDefaults()`
50:    /// in `WealthCore.swift`.  Once the core file is refactored, remove the
51:    /// original stub and keep only this implementation.
52:    func resetToFactoryDefaults() {
53:        WealthEngineStartupController.shared.cancelStartupSequence()
54:        invalidateTimers()
        ...
67:    }
```

**Technical Impact:**
- The comment explicitly acknowledges that `WealthCore.swift` already contains a stub implementation of `resetToFactoryDefaults()`.
- In Swift, you cannot have two functions with identical signatures in the same type, even across files in the same module. The Swift compiler emits `error: redeclaration of 'resetToFactoryDefaults()'` and the project does not build.
- This is a **hard build failure** on any machine that compiles both `WealthCore.swift` and `WealthEngineStore+Recovery.swift` together.

**Same Pattern Risk — Also Check:**  
The comment style `// NOTE: This method extends (replaces) the stub ... in WealthCore.swift` appears in multiple files. Any function defined in `WealthCore.swift` that also appears in the committed extensions (even with different bodies) is a potential compilation redeclaration error.

---

## Theme 4 — Cache Integrity: Data Loss and Main-Thread Blocking

---

### BUG-7 🔴 CRITICAL — `restoreCache()` Claims Not to Decode Large Arrays But Does

**File:** `WealthEngineStore+Cache.swift`  
**Lines:** 62–76  
**Function:** `restoreCache()`

```
62:    /// Large array decoding is **not** performed here – call
63:    /// `restoreCacheInBackground(completion:)` (from
64:    /// `WealthEngineStore+BackgroundCache.swift`) to avoid blocking the
65:    /// main thread.  This synchronous variant restores timestamps only and
66:    /// is kept for compatibility with any call site that cannot be made async.
67:    func restoreCache() {
68:        let defaults = UserDefaults.standard
69:        if let stored = defaults.object(forKey: DefaultsKey.lastRefresh) as? Date {
70:            lastRefresh = stored
71:        }
72:        ...
73:        restoreRankedAssetsFromFile()      // ← decodes rankedAssets JSON on calling thread
74:        restoreScannedSignalsFromFile()    // ← decodes scannedSignals JSON on calling thread
75:        restoreHoldingsFromFile()          // ← decodes holdings JSON on calling thread
76:    }
```

**Technical Impact:**
- The documentation comment explicitly states that large array decoding is NOT performed in `restoreCache()` and that it "restores timestamps only." This is false.
- Lines 73–75 call three private helper functions that perform full `JSONDecoder().decode(...)` operations on potentially very large arrays (128k ranked assets, scan signals, holdings).
- `restoreCache()` is a synchronous function with no `async`/`await`. Any call site that invokes it on the main thread (e.g. `WealthEngineStore+Recovery.swift` line 32: `restoreCache()` inside `recoverFromFailedRefresh()`) will block the main thread for as long as it takes to decode all three JSON files.
- On a device with a stale 128k-card cache, this can block the main thread for several seconds, causing the UI to freeze, potentially triggering the iOS watchdog timer, and resulting in an app kill.
- **The misleading documentation makes this bug invisible to future maintainers**, who will assume the synchronous `restoreCache()` path is safe to call from the main thread.

---

### BUG-14 🟡 MEDIUM — JSON Decode Failures Silently Swallowed in Background Cache Restore

**File:** `WealthEngineStore+BackgroundCache.swift`  
**Lines:** 62–71  
**Function:** `restoreCacheInBackground(completion:)`

```
61:            if let url = cacheDir?.appendingPathComponent("awc_engine_ranked_assets.json"),
62:               let data = try? Data(contentsOf: url) {
63:                restoredAssets = try? JSONDecoder().decode([Opportunity].self, from: data)
64:            }
```

**Technical Impact:**
- `try?` silently discards all errors. If a JSON file exists but contains corrupt or schema-mismatched data (e.g. from a partial write during a previous crash, or after a model migration), `restoredAssets` is set to `nil` with no log, no error, and no indication to the user or developer.
- A previously successful cache write could silently become unreadable after a model update, causing the UI to appear empty on relaunch without any diagnostic information about why.
- The `WealthEventLogStore` record posted on completion (line 82–87) reports the count of assets but does not distinguish between "file absent" (expected at first launch) and "file present but undecodable" (silent corruption).

---

## Theme 5 — Concurrency: Race Conditions and Unsafe Patterns

---

### BUG-8 🔴 CRITICAL — Timer Callbacks Spawn Concurrent Scan Tasks Without In-Flight Guard

**File:** `WealthEngineStore+Timers.swift`  
**Lines:** 97–133  
**Functions:** `makeIBKRTimer()`, `makeSoftTimer()`, `makeDeepTimer()`

```
96:    private func makeIBKRTimer(at interval: TimeInterval, stage: Int) -> Timer {
97:        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
98:            guard let self else { return }
99:            Task { @MainActor [weak self] in
100:                guard let self else { return }
101:                self.activationStage = stage
102:                Task.detached(priority: .userInitiated) { [weak self] in
103:                    await self?.refresh(mode: .ibkr)     // ← no guard on previous cycle
104:                }
105:            }
106:        }
107:    }
```

**Technical Impact:**
- All three timer factory functions (`makeIBKRTimer`, `makeSoftTimer`, `makeDeepTimer`) spawn a `Task.detached` when the timer fires. There is **no check** to determine whether a previous scan cycle from the same (or another) timer is still running.
- If a 10-minute soft refresh takes more than 10 minutes (e.g., on a slow connection or under high CPU load), the next timer fires and spawns a second concurrent refresh cycle, which begins modifying `rankedAssets`, `scannedSignals`, and other shared state at the same time.
- The deep-refresh timer at 30 minutes fires at the same wall-clock time as the 10-minute soft timer (since 30 is a multiple of 10). Both `runDeepRefresh()` and `runSoftRefresh()` call `runUniverseScan()`, `runAIScan()`, and `runMarketRanking()` — meaning all three phases execute twice concurrently.
- While individual @MainActor operations on shared state are serialized, the overall multi-step pipeline (universe scan → AI scan → market ranking) is NOT atomic. Two concurrent pipelines can interleave: Pipeline A sets `rankedAssets` from its universe scan, Pipeline B begins its AI scan on that data, Pipeline A then overwrites `rankedAssets` again from its second AI scan.
- **Net effect:** Random, non-reproducible data corruption on every multi-cycle overlap event. This manifests as cards appearing and disappearing, rankings jumping, and occasional zero-card states.

---

### BUG-11 🟠 HIGH — Strong Self-Capture Creates Retain Cycle in `activationTask`

**File:** `WealthEngineStore+Activation.swift`  
**Line:** 54  
**Function:** `runActivationSequence()`

```
54:        activationTask = Task { @MainActor [self] in
```

**Technical Impact:**
- `activationTask` is a stored property on `self` (WealthEngineStore).
- The Task captures `self` **strongly** via `[self]`.
- This creates a reference cycle: `self.activationTask` → Task → strongly holds `self`.
- Because `WealthEngineStore.shared` is a singleton, the practical memory impact is negligible. However, the retain cycle prevents `deinit` from ever running if the singleton is ever replaced (e.g., during unit tests or test environments), and it means the engine cannot be released even if the user signs out and the singleton is meant to be replaced.
- The pattern also conflicts with the `defer { activationTask = nil }` at line 63: the defer correctly breaks the cycle on normal completion, but it relies on the Task executing its body fully. A `Task.cancel()` called before the inner `Task.detached` body runs will still trigger the defer (on the outer task), but the inner detached task has no cancellation check before its MainActor.run block completes.

---

## Theme 6 — Lifecycle Management: Activity Never Populates

---

### BUG-12 🟠 HIGH — Multiple Retry Chains Can Accumulate in `WealthPortfolioLifecycleHelper`

**File:** `WealthPortfolioStore+LifecycleHelpers.swift`  
**Lines:** 54–91  
**Function:** `handleEngineReady()`, `scheduleArmedRetry()`

```
54:    private func handleEngineReady() {
55:        if WealthPortfolioStore.shared.tradingLifecycleArmed {
56:            triggerAdmissionRerun()
57:        } else {
58:            scheduleArmedRetry(attemptsRemaining: maxRetryAttempts)  // starts chain
59:        }
60:    }
```

```
83:        retryTask = Task { [weak self] in
84:            try? await Task.sleep(nanoseconds: 1_000_000_000)
85:            guard !Task.isCancelled, let self else { return }
86:            if WealthPortfolioStore.shared.tradingLifecycleArmed {
87:                self.triggerAdmissionRerun()
88:            } else {
89:                self.scheduleArmedRetry(attemptsRemaining: attemptsRemaining - 1)
90:            }
91:        }
```

**Technical Impact:**
- `handleEngineReady()` is triggered by the `wealthEngineDidBecomeReady` notification. If this notification fires more than once (e.g., after a downstream rebuild completes), `handleEngineReady()` is called again while a retry chain is still running.
- Each call to `scheduleArmedRetry()` overwrites `retryTask` with a new Task, but **does not cancel the previous Task**. The old Task's `guard !Task.isCancelled` check will not fire because the old task was never cancelled — only its tracking reference was lost.
- After `n` notification firings without `tradingLifecycleArmed` becoming true, there are `n` concurrent retry chains each polling once per second, each capable of calling `triggerAdmissionRerun()` independently.
- Multiple concurrent `rerunActivityAdmissionAfterStartup()` calls will fire `reconcileActivityAdmissions()` multiple times in parallel, which is not designed to be re-entrant.
- **Net effect:** Activity may have `reconcileActivityAdmissions()` called multiple times concurrently, leading to duplicate admissions, inconsistent queue state, or silent data overwrite.

---

## Theme 7 — IBKR Bridge: Architecture and Security Issues

---

### BUG-9 🟠 HIGH — `receiveBuffer` Is Not Private; NWConnection Uses Main Queue

**File:** `WealthIBKRBridge.swift`  
**Lines:** 64, 96

```
64:    var receiveBuffer = Data()       // ← internal access, no modifier
...
96:    conn.start(queue: .main)         // ← uses main queue for all callbacks
```

**Technical Impact (line 64 — `receiveBuffer`):**
- `receiveBuffer` has no access modifier, defaulting to `internal`. Any code in the same module can read or write directly to the live receive buffer.
- External writes to `receiveBuffer` would corrupt the TWS protocol frame parser in `processReceiveBuffer()`, potentially causing buffer overflows in the length-prefix parser (lines 154–163) or tripping the handshake state machine.
- The field should be `private var receiveBuffer = Data()`.

**Technical Impact (line 96 — `.main` queue):**
- `conn.start(queue: .main)` means all NWConnection state updates and receive completions are initially dispatched to the main `DispatchQueue`. The `Task { @MainActor in }` wrappers in `startReceiving()` and `stateUpdateHandler` hop to the main actor, which is correct, but using `.main` for the connection's underlying queue means the network I/O scheduling is tied to the main run loop.
- On a congested main thread (during heavy SwiftUI layout or a scan cycle), the `.main` queue may be backlogged, delaying delivery of incoming TWS messages, including time-sensitive price tick data.
- The `@MainActor`-isolated bridge would be equally correct and more responsive if the connection used a dedicated serial background queue for initial dispatch, with only the final callback bodies dispatched to the main actor via `Task { @MainActor in }` (as already done).

---

### BUG-10 🟠 HIGH — Hardcoded Private LAN IP Address Embedded in Production Diagnostic Log

**File:** `WealthIBKRBridge+Send.swift`  
**Line:** 169  
**Function:** `diagnoseRejection(event:)`

```
168:            } else if reason.contains("timed out") || reason.contains("timeout") {
169:                Self.validLog.error(
170:                    "IBKRBridge diagnosis: connection timed out — check LAN route to TWS host (192.168.1.21)"
171:                )
```

**Technical Impact:**
- `192.168.1.21` is a hardcoded private LAN IP address embedded in a production OSLog error message.
- Every user who encounters a connection timeout will see this hardcoded address in their device logs, regardless of where their TWS instance actually runs.
- For users where TWS is on a different host (or where this is a production app for multiple users), this message is actively misleading and will send them troubleshooting in the wrong direction.
- The address also leaks internal network topology in any crash logs, device diagnostics, or log aggregators (e.g., Firebase Crashlytics), which is a minor security concern in a financial application.
- This should use a configurable host constant, not a hardcoded address.

---

## Theme 8 — Logic Errors and Code Quality

---

### BUG-13 🟡 MEDIUM — Double-Setting `isMarketMaterializationInFlight = false` (Redundant + Misleading)

**File:** `WealthEngineStore+Materialization.swift`  
**Lines:** 73–94  
**Function:** `materializeMarketCandidates()`

```
73:        isMarketMaterializationInFlight = true
74:
75:        defer { isMarketMaterializationInFlight = false }   // ← defers reset to function exit
76:
77:        let routed = WealthCardHoldingRouter.routeFromGreenCheckpoint(rankedAssets)
...
83:        if !recheckPassed.allSatisfy(\.isMarketExecutableCandidate) {
...
92:            isMarketMaterializationInFlight = false   // ← REDUNDANT: defer already handles this
93:            return
94:        }
```

**Technical Impact:**
- The explicit `isMarketMaterializationInFlight = false` at line 92 is redundant because the `defer` block at line 75 will unconditionally set the flag to `false` when the function returns.
- While harmless at runtime (setting a Bool to false twice is idempotent), this is an active maintenance hazard: a future developer adding a `guard !Task.isCancelled else { return }` check or a second early-return path may model their code after this pattern and accidentally omit the defer, causing the in-flight flag to get permanently stuck at `true` (which would prevent all subsequent market materialization passes from running).
- It also undermines the `assertionFailure` on line 92, which should be the complete failure response — the redundant flag reset implies the developer is unsure whether `defer` will run, which suggests a misunderstanding of Swift defer semantics.

---

### BUG-15 🟡 MEDIUM — Unnecessary Double Task Wrapping for `@MainActor` Scan Functions

**File:** `WealthEngineStore+Refresh.swift`  
**Lines:** 49–66  
**Functions:** `runUniverseScan()`, `runAIScan()`, `runMarketRanking()`, `runResearchFeeds()`

```
49:    func runUniverseScan() async {
50:        await Task.detached(priority: .userInitiated) { [weak self] in
51:            await self?.performUniverseScan()
52:        }.value
53:    }
```

**Technical Impact:**
- `performUniverseScan()` is marked `@MainActor`. Regardless of which thread calls it, Swift's actor system will always schedule it on the main actor. Using `Task.detached` to call a `@MainActor` function creates an unnecessary thread hop: detach to background thread → immediately hop back to main actor.
- The `Task.detached` adds scheduling overhead and a context switch for zero benefit.
- More significantly: `await Task.detached { }.value` is a blocking-pattern idiom that is semantically different from a simple `await performUniverseScan()`. It creates a new unstructured task with `.userInitiated` priority, which may run ahead of other pending work in the actor queue, causing priority inversion if called from a `.background` priority context.
- This pattern appears four times (universe, AI, market, research) and once more in `runIBKRPriceSync()`.

---

### BUG-16 🟡 MEDIUM — `// MARK:` Comment Embedded on Property Declaration Line

**File:** `WealthStaleCacheDetector.swift`  
**Line:** 46

```
46:    let backgroundFreshnessThreshold: TimeInterval = 30 * 60    // MARK: - Public API
```

**Technical Impact:**
- The `// MARK: - Public API` source comment is appended inline to a property declaration instead of appearing on its own line.
- Xcode's jump bar and source editor parse `// MARK:` comments only when they appear on a standalone line. This MARK will not appear in the jump bar, making the class harder to navigate.
- The `// MARK:` appearing after code (not before the section it marks) is visually confusing — it appears to annotate the property above it rather than the API section below.
- This is a cosmetic issue with a navigation impact in a 125-line file.

---

## Summary: Critical Path to Functional State

The following issues, if unresolved, prevent the application from functioning correctly at all:

| Priority | Bug | Blocking Effect |
|----------|-----|-----------------|
| P0 | BUG-5 | App does not compile (missing `endDashboardRefreshFreeze`) |
| P0 | BUG-6 | App does not compile (duplicate `resetToFactoryDefaults`) |
| P1 | BUG-1 | Universe, research, IBKR scans deliver no data |
| P1 | BUG-2 | All post-handshake TWS data silently dropped |
| P1 | BUG-3 | Brain never learns; AI scoring never adapts |
| P1 | BUG-4 | Safeguard gate uses wrong risk signals; wrong cards blocked/allowed |
| P2 | BUG-7 | `restoreCache()` freezes UI despite documentation claiming it is safe |
| P2 | BUG-8 | Concurrent timer cycles cause scan-data races and ranking corruption |
| P3 | BUG-9 | `receiveBuffer` exposed without access control; wrong connection queue |
| P3 | BUG-10 | Hardcoded LAN IP misleads users; leaks topology in logs |
| P3 | BUG-11 | Retain cycle in activation task (benign for singleton, test hazard) |
| P3 | BUG-12 | Multiple retry chains can trigger Activity reconciliation concurrently |

---

## Architectural Narrative

The AWC codebase is a **well-structured extension layer built on top of a missing core**. The 33 committed Swift files represent a sophisticated orchestration harness: lifecycle management, scan scheduling, cache sanity checks, audit instrumentation, brain ingest coordination, IBKR bridge framing, and downstream rebuild orchestration. Every system is correctly wired together.

The fatal flaw is that `WealthCore.swift` — the file containing the actual data-loading, AI-scoring, and order-execution implementations — is not committed to the repository. The committed code is the skeleton; the muscle is absent. Every scan phase (`performUniverseScan`, `performResearchFeeds`, `performIBKRSync`) and every brain operation (`learn`, `bias`) are stubbed with single-line comments pointing back to `WealthCore.swift`.

The two hardest-impact bugs are the **placeholder risk properties** (`earningsRisk`, `macroRisk`) and the **IBKR message handler stub**. Both are in committed code (not in WealthCore.swift) and both will actively produce wrong behavior at runtime even when the missing WealthCore.swift is present. The placeholder risk properties in `Opportunity+CardStateMachine.swift` are particularly dangerous because the code itself documents that it "WILL produce incorrect safeguard decisions in production" — this is a production-admitted defect that gates the entire market ranking pipeline.

The **compilation failures** (BUG-5, BUG-6) mean the project as committed cannot be built on any machine that also has `WealthCore.swift`, because of function redeclaration conflicts. These must be resolved before any runtime testing is possible.

The **concurrency issue** in the timer system (BUG-8) is a latent production bug that will not manifest in normal testing (where scan cycles complete quickly) but will appear under real-world network delays, causing non-reproducible ranking corruption on every timer cycle overlap.

---

*End of audit report. No code changes were made. All findings are diagnostic only.*
