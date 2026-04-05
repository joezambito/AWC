import Foundation

// MARK: - WealthEngineScanScheduler (coordinator stub)
//
// In the real Xcode project, the activation and scheduling logic lives
// in `extension WealthEngineStore` in WealthEngineScanScheduler.swift.
//
// This stub satisfies references from WealthEngineStartupController.swift
// which calls `WealthEngineScanScheduler.shared.markPhaseComplete(_:)`.
// These calls are no-ops here; the real phase tracking is handled by the
// inline extension methods on WealthEngineStore.

enum StartupPhaseKey {
    case cacheRestore
    case universeScan
    case aiScan
    case marketRanking
    case researchFeeds
}

@MainActor
final class WealthEngineScanScheduler {

    static let shared = WealthEngineScanScheduler()
    private init() {}

    /// Records that a startup phase has completed.
    ///
    /// No-op in this stub; phase tracking is handled by WealthEngineStore
    /// extension methods in the real Xcode project.
    func markPhaseComplete(_ phase: StartupPhaseKey) {}
}
