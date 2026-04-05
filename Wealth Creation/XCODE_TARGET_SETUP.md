# Xcode Target Setup — Required Manual Step

## Why this file exists

The 40 Swift source files in the `Wealth Creation/` directory are committed
to git but are **not yet included in the Xcode project target**.  Xcode only
compiles files that appear in the `.xcodeproj` target membership list.  Until
these files are added to the target, all the engine fixes, orchestrators,
auditors, and startup controllers in this directory are **dead code** — they
are never compiled and the app runs entirely on the original `WealthCore.swift`.

This is the single most impactful action needed to activate all fixes.

---

## How to add the files in Xcode

1. Open `Wealth Creation.xcodeproj` in Xcode.
2. In the **Project Navigator** (⌘1), right-click the `Wealth Creation` group
   (the folder that already contains `WealthCore.swift`, `ContentView.swift`, etc.).
3. Choose **Add Files to "Wealth Creation"…**
4. Navigate to the `Wealth Creation/` folder in your repository checkout.
5. Select **all 40 `.swift` files listed below**.
6. Make sure **"Add to targets: Wealth Creation"** is checked.
7. Click **Add**.
8. Build the project (⌘B).  The compiler will flag any symbol conflicts
   between the new files and `WealthCore.swift`; see the migration notes below.

---

## Files to add (40 total)

```
AWCSecretConfig.swift
MarketDataFetcher.swift
Opportunity+CardStateMachine.swift
PersistenceManager.swift
WealthAILiveCoordinator+Evaluation.swift
WealthAILiveRejectionAudit.swift
WealthActivityAdmissionAudit.swift
WealthAppSessionController.swift
WealthBrainStore.swift
WealthDownstreamCacheSanity.swift
WealthDownstreamRebuildOrchestrator.swift
WealthEngineRefresh+LifecyclePublishing.swift
WealthEngineRuntimeCoordinator.swift
WealthEngineRuntimeRecovery.swift
WealthEngineScanScheduler.swift
WealthEngineStartupController.swift
WealthEngineStore+Activation.swift
WealthEngineStore+BackgroundCache.swift
WealthEngineStore+Bootstrap.swift
WealthEngineStore+Cache.swift
WealthEngineStore+Dashboard.swift
WealthEngineStore+Materialization.swift
WealthEngineStore+Recovery.swift
WealthEngineStore+Refresh.swift
WealthEngineStore+Timers.swift
WealthEngineStore+UniverseBlueprints.swift
WealthEngineStore.swift
WealthIBKRBridge+Portfolio.swift
WealthIBKRBridge+Send.swift
WealthIBKRBridge.swift
WealthMarketExecutionAudit.swift
WealthNewComponentsBootstrap.swift
WealthOrderRestrictionRules.swift
WealthPeerSyncService.swift
WealthPortfolioStore+Lifecycle.swift
WealthPortfolioStore+LifecycleHelpers.swift
WealthReadyStateGate.swift
WealthSessionUnlockController.swift
WealthStaleCacheDetector.swift
WealthStartupLagTracer.swift
```

---

## Migration notes (after adding files)

### 1. Class redeclaration conflict
`WealthEngineStore.swift` in this directory declares
`@MainActor final class WealthEngineStore`.  If `WealthCore.swift` also
declares `class WealthEngineStore`, Swift will reject the build with
*"Invalid redeclaration of 'WealthEngineStore'"*.

**Resolution:** Remove the `WealthEngineStore` class body from `WealthCore.swift`
and keep only method bodies that are not yet implemented as stubs in the new
extension files (e.g. `runStartupActivationScan()`, `runStartupMarketWarmup()`).

### 2. bootstrap() entry point
`WealthCore.swift` contains the existing `bootstrap()` call site.  The new
`WealthEngineStore+Bootstrap.swift` overrides `bootstrap()` to route through
`WealthAppSessionController.prepareLaunch()`.  Once the class conflict is
resolved, the new `bootstrap()` takes over automatically — no change to
call sites in `ContentView.swift` or `Wealth_CreationApp.swift` is needed.

### 3. softTimer / heavyTimer
`WealthCore.swift` declares `softTimer` and `heavyTimer` as stored properties
of `WealthEngineStore`.  `WealthEngineStore.swift` (in this directory) also
declares them.  After resolving the class redeclaration, remove the duplicate
property declarations from whichever file you keep as the single class body.

### 4. runActivationSequence()
The new `WealthEngineStore+Activation.swift` replaces the synchronous
`runActivationSequence()` stub in `WealthCore.swift`.  Once both files are in
the target, the extension's version takes precedence because the stub in
`WealthCore.swift` is in the class body — Swift will flag the duplicate.
Remove the stub from `WealthCore.swift` and keep the extension version.
