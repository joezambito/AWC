import Foundation

// MARK: - WealthEngineStartupDependencyMap
//
// ═══════════════════════════════════════════════════════════════════════════
// STARTUP DEPENDENCY MAP
// Complete feature inventory for the AWC startup pipeline.
//
// Purpose:
//   This file is the living reference for every feature, side-effect,
//   @Published property, timer, integration, and recovery path that is
//   touched by the startup system.  Consult this document before adding,
//   removing, or moving startup logic to ensure nothing is accidentally
//   omitted from a consolidated startup sequence.
//
// Files covered:
//   1. WealthEngineRuntimeCoordinator.swift
//   2. WealthEngineStore+Bootstrap.swift
//   3. WealthEngineStore+Activation.swift
//   4. WealthEngineStore+Timers.swift
//   5. WealthEngineStartupController.swift   ← new unified orchestrator
// ═══════════════════════════════════════════════════════════════════════════

// MARK: - 1. Entry-Point Routing
//
// ┌─ ContentView.onAppear ──────────────────────────────────────────────────┐
// │  WealthEngineStore.bootstrap()                                          │
// │    └─ WealthAppSessionController.prepareLaunch()  [guarded: hasLaunched]│
// │         ├─ WealthNewComponentsBootstrap.activate()                      │
// │         │    (registers all NotificationCenter observers –              │
// │         │     audits, cache-sanity, portfolio-lifecycle, AI Live)       │
// │         └─ WealthEngineStore.restoreCacheInBackground {                 │
// │                WealthEngineStartupController.beginStartupSequence()     │
// │            }                                                            │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─ ContentView.onChange(scenePhase == .active) ───────────────────────────┐
// │  WealthEngineStore.handleForegroundActivation()                         │
// │    └─ WealthAppSessionController.applicationDidBecomeActive()           │
// │         └─ WealthEngineRuntimeCoordinator.handleBecameActive()          │
// │              ├─ [debounce: 2 s between consecutive calls]               │
// │              ├─ if startup not complete → no-op                         │
// │              └─ if startup complete →                                   │
// │                   WealthSessionUnlockController.handleSessionResume()   │
// │                     └─ WealthStaleCacheDetector.checkAndRebuildIfNeeded │
// │                          └─ WealthDownstreamRebuildOrchestrator.trigger │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─ App enters background ─────────────────────────────────────────────────┐
// │  WealthAppSessionController.applicationDidEnterBackground()             │
// │    ├─ WealthSessionUnlockController.cancelSessionResume()               │
// │    └─ WealthEngineStore.saveInBackground()                              │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─ App will terminate ────────────────────────────────────────────────────┐
// │  WealthAppSessionController.applicationWillTerminate()                  │
// │    └─ WealthEngineStore.save()   (synchronous final save)               │
// └─────────────────────────────────────────────────────────────────────────┘

// MARK: - 2. Startup Sequence Phases (WealthEngineStartupController)
//
// Phase 0 – Pre-flight integrity check
//   WealthEngineRuntimeRecovery.runStartupIntegrityCheck()
//     Repairs stuck flags from a previous interrupted session:
//       • engine.isDashboardRefreshInFlight  → forced false
//       • engine.isMarketMaterializationInFlight → forced false
//       • engine.activationTask              → forced nil
//       • engine.pendingRefreshPayload       → forced nil
//       • engine.pendingPublishTask          → forced nil
//       • WealthReadyStateGate.reset()
//       • WealthDownstreamRebuildOrchestrator.cancelRebuild()
//   WealthEngineScanScheduler.markPhaseComplete(.cacheRestore)
//     → currentProgress: 0/5 → 1/5 = 20 %
//
// Phase 1 – Universe scan  (background thread)
//   engine.runUniverseScanWithProgress()
//     ├─ posts .wealthRefreshPhaseWillBegin(universeScan)
//     ├─ engine.runUniverseScan()
//     │    └─ performUniverseScan()   [WealthCore.swift – actual data logic]
//     ├─ WealthEngineScanScheduler.markPhaseComplete(.universeScan)
//     │    → currentProgress: 2/5 = 40 %
//     └─ posts .wealthRefreshPhaseDidComplete(universeScan)
//   [wait 2 s]
//
// Phase 2 – AI scan  (background thread)
//   engine.runAIScanWithProgress()
//     ├─ posts .wealthRefreshPhaseWillBegin(aiScan)
//     ├─ engine.runAIScan()
//     │    └─ performAIScan()         [WealthCore.swift – AI scoring]
//     ├─ WealthEngineScanScheduler.markPhaseComplete(.aiScan)
//     │    → currentProgress: 3/5 = 60 %  ← AI Live gate unlocked (≥ 0.5)
//     └─ posts .wealthRefreshPhaseDidComplete(aiScan)
//   [wait 1 s]
//
// Phase 3 – Market ranking  (background thread)
//   engine.runMarketRankingWithProgress()
//     ├─ posts .wealthRefreshPhaseWillBegin(marketRanking)
//     ├─ engine.runMarketRanking()
//     │    └─ performMarketRanking()
//     │         └─ materializeMarketCandidates()
//     │              ├─ WealthCardHoldingRouter.routeFromGreenCheckpoint()
//     │              ├─ safeguard gate (earningsRisk, macroRisk, stale, execution, anomaly)
//     │              ├─ 50 % data/score re-check
//     │              ├─ assignMarketRanks()
//     │              └─ WealthAllCardsStore.shared.sync(...)    ← UI updated
//     ├─ WealthEngineScanScheduler.markPhaseComplete(.marketRanking)
//     │    → currentProgress: 4/5 = 80 %
//     └─ posts .wealthRefreshPhaseDidComplete(marketRanking)
//   [wait 1 s]
//
// Phase 4 – Research feeds  (background thread)
//   engine.runResearchFeedsWithProgress()
//     ├─ posts .wealthRefreshPhaseWillBegin(researchFeeds)
//     ├─ engine.runResearchFeeds()
//     │    └─ performResearchFeeds()  [WealthCore.swift – research intel]
//     ├─ WealthEngineScanScheduler.markPhaseComplete(.researchFeeds)
//     │    → currentProgress: 5/5 = 100 %
//     └─ posts .wealthRefreshPhaseDidComplete(researchFeeds)
//
// Phase 5 – Finalise  (MainActor)
//   engine.finalizeActivationState()
//     Sets @Published properties (see Section 3 below)
//   WealthEngineStartupController.isStartupComplete = true
//   engine.rescheduleTimers()
//     Starts 6 recurring timers (see Section 5 below)
//   WealthEventLogStore record: "Startup sequence complete."

// MARK: - 3. @Published Properties Set During Startup
//
// These properties are observed by the UI or downstream systems.
// ALL of them must be set (or left unchanged) when consolidating startup.
//
// ┌────────────────────────────┬────────────────────────────────────────────┐
// │ Property                   │ Effect when set                            │
// ├────────────────────────────┼────────────────────────────────────────────┤
// │ startupSequencePhase       │ .waitingToScan → .idle                     │
// │                            │  Drives loading UI / progress indicators   │
// ├────────────────────────────┼────────────────────────────────────────────┤
// │ activationStage = 0        │ Resets the stage counter used by the UI    │
// │                            │  to show multi-step progress               │
// ├────────────────────────────┼────────────────────────────────────────────┤
// │ activationCycleComplete    │ true → downstream refreshes are allowed    │
// │   = true                   │  (guards in WealthCore.swift check this)   │
// ├────────────────────────────┼────────────────────────────────────────────┤
// │ lockedCheckpointProgress   │ Seeds checkpoint counter for the first     │
// │   = Self.lockedCheckpoint- │  timer cycle. Determines when the first    │
// │     Count                  │  IBKR/Soft checkpoint is "overdue"         │
// ├────────────────────────────┼────────────────────────────────────────────┤
// │ tradingLifecycleArmed      │ **CRITICAL** – must be true for Activity   │
// │   = true                   │  admission to run.                         │
// │                            │  Checked by:                               │
// │                            │  • WealthPortfolioStore.reconcileActivity- │
// │                            │    Admissions() (gate: returns if false)   │
// │                            │  • WealthPortfolioLifecycleHelper          │
// │                            │    .handleEngineReady() (polls until true) │
// ├────────────────────────────┼────────────────────────────────────────────┤
// │ downstreamRecoveryPending  │ Set true at start of activation sequence;  │
// │                            │  set false when startup finishes.          │
// │                            │  Tells recovery logic whether a full       │
// │                            │  re-activation is already running.         │
// ├────────────────────────────┼────────────────────────────────────────────┤
// │ rankedAssets               │ Restored from file cache before scan runs. │
// │                            │ Populated/updated by every universe scan.  │
// │                            │ Drives: Dashboard, Market card list,       │
// │                            │  materialization, AI Live evaluation       │
// ├────────────────────────────┼────────────────────────────────────────────┤
// │ scannedSignals             │ Restored from file cache; updated by scans │
// │                            │  Drives: signal list UI                    │
// ├────────────────────────────┼────────────────────────────────────────────┤
// │ holdings                   │ Restored from file cache; updated by sync  │
// │                            │  Drives: portfolio views, PnL calc         │
// ├────────────────────────────┼────────────────────────────────────────────┤
// │ lastRefresh                │ Restored from UserDefaults; updated after  │
// │                            │  each scan. Drives: stale-cache detection  │
// │                            │  (5-min threshold in                       │
// │                            │  WealthStaleCacheDetector.isCacheStale())  │
// ├────────────────────────────┼────────────────────────────────────────────┤
// │ lastHeavyRefresh           │ Same as lastRefresh but for deep (30 m)    │
// │                            │  refresh cycles                            │
// └────────────────────────────┴────────────────────────────────────────────┘

// MARK: - 4. State Management Affecting Other Systems
//
// a) Scan Progress Gate  (WealthEngineScanScheduler)
//    • currentProgress  (0.0 – 1.0)  updated as each scan phase finishes.
//    • hasReachedAILiveGate = (currentProgress ≥ 0.5)
//    • Used by: WealthAILiveCoordinator.evaluateCandidates()
//      If gate not reached → evaluation is skipped → promotedCards stays empty
//      → Activity never populates.
//    • RISK: If any scan phase is removed, progress never reaches 0.5, AI Live
//      never fires.
//
// b) Ready-State Gate  (WealthReadyStateGate)
//    • isFullyReady = isStartupComplete AND isDownstreamRebuildComplete
//    • Becomes true only after WealthDownstreamRebuildOrchestrator completes a
//      rebuild pass (runs AI scan + market ranking).
//    • On first transition to true → posts .wealthEngineDidBecomeReady
//    • Observers of .wealthEngineDidBecomeReady:
//        – WealthNewComponentsBootstrap   → runPostReadyPipeline()
//        – WealthDownstreamCacheSanity    → validatePersistedDownstreamState()
//        – WealthPortfolioLifecycleHelper → handleEngineReady()
//    • RISK: If the startup controller never sets isStartupComplete = true,
//      the gate never opens, no audits run, Activity stays empty.
//
// c) trading­Lifecycle­Armed  (WealthEngineStore)
//    • Must be true before WealthPortfolioStore.reconcileActivityAdmissions()
//      proceeds.
//    • Set by finalizeActivationState() at end of startup sequence.
//    • RISK: If missing, Activity is permanently empty until next timer tick
//      (up to 30 min).
//
// d) Stale-Cache State  (WealthStaleCacheDetector + WealthDownstreamCacheSanity)
//    • checkAndRebuildIfNeeded() fires when:
//        – Market cards present but AI scores all zero
//        – lastRefresh older than 5 min
//        – AI Live results file missing or >30 min old
//        – Activity state file missing or >30 min old
//    • Triggers WealthDownstreamRebuildOrchestrator.triggerRebuild()
//    • RISK: If cache timestamps are not updated after scans, every foreground
//      resume triggers a full rebuild unnecessarily.

// MARK: - 5. Timer-Dependent Features (WealthEngineStore+Timers)
//
// All 6 timers are scheduled by rescheduleTimers() at the END of startup.
// Without these timers, the app becomes static after launch.
//
// ┌──────────┬───────────┬──────────────────────────────────────────────────┐
// │ Property │ Interval  │ Drives                                           │
// ├──────────┼───────────┼──────────────────────────────────────────────────┤
// │ ibkr[0]  │  9 min    │ refresh(mode:.ibkr) → performIBKRSync()          │
// │          │           │  Live IBKR broker prices, fills, positions       │
// ├──────────┼───────────┼──────────────────────────────────────────────────┤
// │ softTimer│ 10 min    │ refresh(mode:.soft) → universe + AI + market     │
// │          │           │  Light data refresh; scores + rankings update    │
// ├──────────┼───────────┼──────────────────────────────────────────────────┤
// │ ibkr[1]  │ 19 min    │ refresh(mode:.ibkr)   (same as ibkr[0])          │
// ├──────────┼───────────┼──────────────────────────────────────────────────┤
// │ extraSoft│ 20 min    │ refresh(mode:.soft)   (same as softTimer)        │
// ├──────────┼───────────┼──────────────────────────────────────────────────┤
// │ ibkr[2]  │ 29 min    │ refresh(mode:.ibkr)   (same as ibkr[0])          │
// ├──────────┼───────────┼──────────────────────────────────────────────────┤
// │ heavyTimer│ 30 min   │ refresh(mode:.deep) → universe + AI + market +   │
// │          │           │  research feeds (full pipeline every 30 min)     │
// └──────────┴───────────┴──────────────────────────────────────────────────┘
//
// Timer storage:
//   • softTimer, heavyTimer        – stored properties on WealthEngineStore
//   • ibkrTimers, extraSoftTimers  – stored in WealthTimerHolder (file-private)
//     because Swift extensions cannot add stored properties.
//
// RISK: If invalidateTimers() is called without also clearing
//   timerHolder.ibkrTimers and timerHolder.extraSoftTimers, IBKR price
//   updates and the second soft refresh will leak and continue firing.

// MARK: - 6. Cache Restoration Logic
//
// Called BEFORE beginStartupSequence() so UI is populated immediately.
//
// WealthEngineStore.restoreCacheInBackground(completion:)
//   (Task.detached – never blocks main thread)
//   ├─ UserDefaults → lastRefresh, lastHeavyRefresh
//   ├─ Caches/awc_engine_ranked_assets.json   → rankedAssets   (may be 128k cards)
//   ├─ Caches/awc_engine_scanned_signals.json → scannedSignals
//   └─ Caches/awc_engine_holdings.json        → holdings
//   On completion → calls beginStartupSequence()
//
// File-backed downstream caches (WealthDownstreamCacheSanity):
//   • awc_ai_live_results.json   – AI Live promoted cards
//   • awc_market_snapshot.json   – top-N ranked market candidates
//   • awc_activity_state.json    – admitted Activity card symbols
//   Freshness threshold: 30 minutes (matches deep-refresh timer)
//
// RISK: If the completion closure passed to restoreCacheInBackground() is
//   dropped or never called, beginStartupSequence() never fires.

// MARK: - 7. Dashboard Refresh & UI State
//
// isDashboardRefreshInFlight (Bool, WealthEngineStore)
//   • Drives: WealthEngineStore.DashboardSnapshot.isDashboardLoading
//   • Set true  by: beginDashboardRefresh()
//   • Set false by: endDashboardRefresh() OR finalizeActivationState()
//     (via WealthEngineRuntimeRecovery.runStartupIntegrityCheck on next launch)
//   • RISK: If a scan phase crashes without calling endDashboardRefresh(),
//     the spinner spins forever.  The integrity check resets it on next boot.
//
// DashboardSnapshot (WealthEngineStore)
//   Bundles: lastRefresh, rankedAssets, holdings, totalPnL, tradingCapital,
//            portfolioValue, isDashboardLoading
//   Built by: makeDashboardSnapshot() – pure read, no side-effects
//   Updated via: publishDashboardUpdate() → objectWillChange.send()
//   Called by: endDashboardRefresh(), beginDashboardRefresh()

// MARK: - 8. Warm-Start / Recovery Paths
//
// a) Warm-start cache reuse (inside legacy runActivationSequence)
//    WealthMarketUniverseStore.prepareCachedSnapshotForStartup()
//    Returns true  → universe cache valid, skip network reload
//    Returns false → full WealthMarketUniverseStore.reloadForStartupSequence()
//    The new startup controller's runUniverseScanWithProgress() calls
//    performUniverseScan() which must implement the same cache-first logic
//    inside WealthCore.swift.
//
// b) Active-session resume recovery  (WealthEngineRuntimeCoordinator)
//    Triggered by: ContentView.onChange(scenePhase == .active) AFTER startup
//    Path: handleBecameActive() → WealthSessionUnlockController.handleSessionResume()
//            → WealthStaleCacheDetector.checkAndRebuildIfNeeded()
//              → WealthDownstreamRebuildOrchestrator.triggerRebuild()
//    Result: AI scan + market ranking re-run; scores refreshed without full startup.
//    Debounced: 2-second minimum between successive calls.
//
// c) Full recovery (WealthEngineRuntimeRecovery.performFullRecovery)
//    Triggered by: persistent decode failures, factory reset, sign-out
//    Path: cancelRebuild() → cancelSessionResume() → ReadyStateGate.reset()
//            → engine.recoverFromFailedRefresh(reason:)
//                ├─ Clears: isDashboardRefreshInFlight, isMarketMaterializationInFlight
//                ├─ Nils:   activationTask, pendingRefreshPayload, pendingPublishTask
//                └─ Calls: restoreCache() (synchronous last-known-good restore)
//
// d) Factory reset (WealthEngineStore.resetToFactoryDefaults)
//    Path: cancelStartupSequence() → invalidateTimers()
//            → clears all @Published arrays (rankedAssets, scannedSignals, holdings)
//            → clears UserDefaults timestamps
//            → removes all Caches JSON files
//            → WealthDownstreamCacheSanity.invalidateAllFileCaches()

// MARK: - 9. Store Integrations
//
// Stores directly called during startup or by startup-triggered code:
//
// WealthMarketUniverseStore
//   • prepareCachedSnapshotForStartup()  – warm-start universe cache
//   • reloadForStartupSequence()         – cold-start universe network load
//   Used by: runActivationSequence (legacy) and performUniverseScan (new)
//
// WealthAllCardsStore
//   • marketCardLimit (static, 100)     – cap on market candidates
//   • shared.sync(opportunities:activityKeys:holdingKeys:livePickKeys:refreshTime:)
//     Called by: materializeMarketCandidates() after every market ranking pass
//     Side-effect: ALL card-list UI (Market, Activity, Holdings) re-renders
//
// WealthPortfolioStore
//   • tradingLifecycleArmed             – read; must be true for admission
//   • reconcileActivityAdmissions()     – Activity admission pass
//   • rerunActivityAdmissionAfterStartup() – post-startup re-run gate wrapper
//   Triggered by: WealthPortfolioLifecycleHelper after wealthEngineDidBecomeReady
//
// WealthEventLogStore
//   • record(title:detail:category:tintName:timestamp:) – used throughout
//   Drives: diagnostic log UI (every system writes events here)

// MARK: - 10. NotificationCenter Signals
//
// Posted DURING or AFTER startup:
//
//   .wealthScanProgressDidUpdate   – after each markPhaseComplete() call
//     userInfo: ["progress": Double]
//     Observed by: any UI component showing scan progress %
//
//   .wealthRefreshPhaseWillBegin   – before each scan phase starts
//     userInfo: ["phase": Int (ScanPhase.rawValue)]
//
//   .wealthRefreshPhaseDidComplete – after each scan phase finishes
//     userInfo: ["phase": Int (ScanPhase.rawValue)]
//
//   .wealthEngineDidBecomeReady    – once, when isStartupComplete AND
//                                    isDownstreamRebuildComplete are both true
//     No userInfo.
//     Observed by:
//       1. WealthNewComponentsBootstrap → runPostReadyPipeline()
//            (runs all audits: market-execution, AI Live rejection,
//             order restriction, activity admission)
//       2. WealthDownstreamCacheSanity → validatePersistedDownstreamState()
//       3. WealthPortfolioLifecycleHelper → handleEngineReady()
//            (triggers Activity admission re-run)

// MARK: - 11. Consolidation Safety Checklist
//
// When merging these files into a single startup file, verify each item:
//
//  [x] Cache is restored BEFORE beginStartupSequence() fires
//  [x] WealthNewComponentsBootstrap.activate() called before startup
//  [x] WealthEngineRuntimeRecovery.runStartupIntegrityCheck() is first step
//  [x] WealthEngineScanScheduler.markPhaseComplete(.cacheRestore) called
//  [x] Universe scan runs first and waits 2 s before AI scan
//  [x] AI scan waits 1 s before market ranking; market waits 1 s before research
//  [x] Each phase uses the WithProgress() wrappers (not bare runXxx())
//  [x] finalizeActivationState() called BEFORE rescheduleTimers()
//  [x] isStartupComplete = true set in WealthEngineStartupController
//  [x] rescheduleTimers() called LAST (only after engine state is fully stamped)
//  [x] invalidateTimers() clears BOTH the stored properties AND timerHolder arrays
//  [x] Scene-phase .active routes to WealthSessionUnlockController (not bootstrap)
//  [x] Scene-phase .background cancels session resume + saves cache
//  [x] Recovery path (recoverLiveUpdatesIfNeeded / recoverFromFailedRefresh) preserved
//  [x] tradingLifecycleArmed = true is set (gates Activity admission)
//  [x] activationCycleComplete = true is set (gates downstream refreshes)
//  [x] downstreamRecoveryPending cleared after startup
//  [x] All 6 timers (3 IBKR + 2 soft + 1 deep) created and retained
//  [x] WealthAllCardsStore.sync() is called during market ranking pass

// MARK: - File (intentionally contains only documentation comments)
//
// No executable code is defined in this file.  All implementation lives in
// the files listed at the top of this document.
