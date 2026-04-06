import Foundation

@MainActor
final class WealthDownstreamRebuildOrchestrator {

    static let shared = WealthDownstreamRebuildOrchestrator()
    private init() {}

    private var rebuildTask: Task<Void, Never>?

    // MARK: - Public API

    func triggerRebuild(reason: String) {
        guard rebuildTask == nil else { return }

        WealthEventLogStore.shared.record(
            title: "Downstream Rebuild",
            detail: "Rebuild triggered: \(reason)",
            category: "orchestration",
            tintName: "blue",
            timestamp: .now
        )

        rebuildTask = Task { [weak self] in
            await self?.performDownstreamRebuild()
            self?.rebuildTask = nil
        }
    }

    func cancelRebuild() {
        rebuildTask?.cancel()
        rebuildTask = nil
    }

    // MARK: - Private pipeline

    private func performDownstreamRebuild() async {
        let engine = WealthEngineStore.shared

        await engine.runAIScan()
        guard !Task.isCancelled else { return }

        await engine.runMarketRanking()
        guard !Task.isCancelled else { return }

        await MainActor.run {
            engine.lastRefresh = Date()
        }

        WealthReadyStateGate.shared.markDownstreamRebuildComplete()
    }
}
