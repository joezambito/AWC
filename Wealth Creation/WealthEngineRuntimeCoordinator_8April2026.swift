// WealthEngineRuntimeCoordinator_8April2026.swift
// Wealth Creation — App session coordinator + live-update recovery (8 April 2026)
// Merged from: WealthEngineRuntimeCoordinator + WealthEngineRuntimeRecovery

import SwiftUI
import Foundation

// MARK: - Runtime Coordinator

@MainActor
final class WealthEngineRuntimeCoordinator {
    static let shared = WealthEngineRuntimeCoordinator()

    private var launchTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var sessionActive = false
    private var lastKnownPhase: ScenePhase = .inactive

    private init() {}

    private var canBootstrapOutsideActivePhase: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }

    private var launchDelayNanoseconds: UInt64 { 2_000_000_000 }
    private var heartbeatIntervalNanoseconds: UInt64 { 30_000_000_000 }

    func startUnlockedSession() {
        setSessionEnabled(true, phase: .active)
    }

    func restartUnlockedSession() {
        stopSession(resetEngine: true)
        let resumePhase: ScenePhase = lastKnownPhase == .background ? .active : lastKnownPhase
        setSessionEnabled(true, phase: resumePhase)
    }

    func stopUnlockedSession() {
        setSessionEnabled(false, phase: .inactive)
    }

    func handleScenePhase(_ phase: ScenePhase, isUnlocked: Bool) {
        setSessionEnabled(isUnlocked, phase: phase)
    }

    func setSessionEnabled(_ enabled: Bool, phase: ScenePhase) {
        lastKnownPhase = phase

        guard enabled else {
            if sessionActive || launchTask != nil || heartbeatTask != nil {
                stopSession(resetEngine: true)
            }
            return
        }

        switch phase {
        case .active:
            prepareVisibleStartupState()

            if sessionActive {
                resumeActiveSession()
                return
            }

            scheduleInitialLaunchIfNeeded()

        case .inactive:
            handleInactivePhase()

        case .background:
            handleBackgroundPhase()

        @unknown default:
            break
        }
    }

    private func prepareVisibleStartupState() {
        WealthEngineStore.shared.restorePersistedMarketCacheIfNeeded()
        _ = WealthMarketUniverseStore.shared.prepareCachedSnapshotForStartup()

        if WealthEngineStore.shared.hasUsableWarmStartCardCache {
            WealthEngineStore.shared.applyWarmStartVisibleState()
        }
    }

    private func resumeActiveSession() {
        WealthSyncStore.shared.autoStartBrokerIfNeeded()
        startHeartbeat()
        WealthEngineStore.shared.recoverLiveUpdatesIfNeeded(reason: "active_resume")
    }

    private func scheduleInitialLaunchIfNeeded() {
        guard launchTask == nil else { return }

        launchTask = Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: launchDelayNanoseconds)
            guard !Task.isCancelled else { return }

            if self.sessionActive {
                self.launchTask = nil
                self.startHeartbeat()
                return
            }

            self.sessionActive = true
            self.launchTask = nil

            WealthEngineStore.shared.bootstrap()
            WealthSyncStore.shared.autoStartBrokerIfNeeded()
            self.startHeartbeat()
        }
    }

    private func handleInactivePhase() {
        guard canBootstrapOutsideActivePhase || sessionActive else { return }

        if canBootstrapOutsideActivePhase {
            if !sessionActive {
                sessionActive = true
                WealthEngineStore.shared.bootstrap()
            }
            WealthSyncStore.shared.autoStartBrokerIfNeeded()
            startHeartbeat()
        } else {
            stopHeartbeat()
        }
    }

    private func handleBackgroundPhase() {
        guard canBootstrapOutsideActivePhase || sessionActive else { return }

        if canBootstrapOutsideActivePhase {
            if !sessionActive {
                sessionActive = true
                WealthEngineStore.shared.bootstrap()
            }
            WealthSyncStore.shared.autoStartBrokerIfNeeded()
            WealthEngineStore.shared.rescheduleTimers()
            startHeartbeat()
        } else {
            stopHeartbeat()
        }
    }

    private func stopSession(resetEngine: Bool) {
        launchTask?.cancel()
        launchTask = nil

        stopHeartbeat()
        sessionActive = false

        if resetEngine {
            WealthEngineStore.shared.prepareForFreshLaunch()
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()

        heartbeatTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: heartbeatIntervalNanoseconds)
                guard !Task.isCancelled else { return }
                WealthEngineStore.shared.recoverLiveUpdatesIfNeeded(reason: "heartbeat")
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }
}

// MARK: - Live Update Recovery

extension WealthEngineStore {
    var softRefreshInterval: TimeInterval {
        configuredSoftRefreshMinutes * 60
    }

    var heavyRefreshInterval: TimeInterval {
        configuredHeavyRefreshMinutes * 60
    }

    func recoverLiveUpdatesIfNeeded(reason: String, now: Date = .now) {
        let didRollOver = handleDayRolloverIfNeeded(now: now)

        if !hasBootstrapped || activationTask != nil || pendingRefreshPayload != nil || pendingPublishTask != nil {
            return
        }

        if scheduledCheckpointTimer == nil {
            rescheduleTimers()
        }

        if didRollOver {
            lastDecisionSummary = "Starting new trading day after \(reason)"
            rescheduleTimers()
            return
        }

        if requiresDownstreamLiveRecovery(now: now) {
            downstreamRecoveryPending = true
            runActivationSequence()
            return
        }

        if downstreamRecoveryPending {
            downstreamRecoveryPending = false
        }
    }
}
