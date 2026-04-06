import Foundation
#if canImport(BackgroundTasks) && !targetEnvironment(macCatalyst)
import BackgroundTasks
import SwiftUI

@MainActor
final class WealthBackgroundRefreshCoordinator {
    static let shared = WealthBackgroundRefreshCoordinator()

    private enum Constants {
        static let taskIdentifier = "com.Zulugames.Wealth-Creation.refresh"
    }

    private var registered = false

    private init() {}

    func activate() {
        guard !registered else { return }
        registered = true

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            Task { @MainActor in
                await self.handleAppRefresh(refreshTask)
            }
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active, .inactive, .background:
            scheduleNextRefresh()
        @unknown default:
            scheduleNextRefresh()
        }
    }

    func scheduleNextRefresh(now: Date = .now) {
        let request = BGAppRefreshTaskRequest(identifier: Constants.taskIdentifier)
        request.earliestBeginDate = WealthEngineStore.shared.nextRecurringCheckpointDate(after: now)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
#if DEBUG
            if WealthPipelineTraceLogger.isEnabledForDebugOutput {
                print("[BackgroundRefresh] submit failed: \(error.localizedDescription)")
            }
#endif
        }
    }

    private func handleAppRefresh(_ task: BGAppRefreshTask) async {
        scheduleNextRefresh()

        let work = Task { @MainActor in
            WealthEngineStore.shared.handleDayRolloverIfNeeded()
            return await WealthEngineStore.shared.executeBackgroundScheduledCheckpointIfNeeded()
        }

        task.expirationHandler = {
            work.cancel()
        }

        let success = await work.value
        task.setTaskCompleted(success: success)
    }
}
#endif
