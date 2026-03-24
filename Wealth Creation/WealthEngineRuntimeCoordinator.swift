import SwiftUI
import Foundation

@MainActor
final class WealthEngineRuntimeCoordinator {
    static let shared = WealthEngineRuntimeCoordinator()

    private var launchTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var sessionActive = false
    private var lastKnownPhase: ScenePhase = .inactive

    private init() {}

    func startUnlockedSession() {
        setSessionEnabled(true, phase: .active)
    }

    func restartUnlockedSession() {
        stopSession(resetEngine: true)
        setSessionEnabled(true, phase: lastKnownPhase == .background ? .active : lastKnownPhase)
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
            stopSession(resetEngine: true)
            return
        }

        switch phase {
        case .active:
            let startedFresh = ensureSessionRunning()
            if !startedFresh {
                WealthEngineStore.shared.recoverLiveUpdatesIfNeeded(reason: "foreground")
            }
            startHeartbeat()
        case .inactive:
            _ = ensureSessionRunning()
            startHeartbeat()
        case .background:
            // iOS can still suspend the app, but we should not shut our own
            // runtime down just because the phone screen slept.
            _ = ensureSessionRunning()
            WealthEngineStore.shared.rescheduleTimers()
            startHeartbeat()
        @unknown default:
            break
        }
    }

    private func ensureSessionRunning() -> Bool {
        let engine = WealthEngineStore.shared
        guard !sessionActive else {
            engine.rescheduleTimers()
            return false
        }

        sessionActive = true
        launchTask?.cancel()
        launchTask = Task { @MainActor in
            engine.prepareForFreshLaunch()
            startHeartbeat()
            engine.bootstrap()
        }
        return true
    }

    private func stopSession(resetEngine: Bool) {
        launchTask?.cancel()
        launchTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        sessionActive = false

        if resetEngine {
            WealthEngineStore.shared.prepareForFreshLaunch()
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                WealthEngineStore.shared.recoverLiveUpdatesIfNeeded(reason: "heartbeat")
            }
        }
    }
}
