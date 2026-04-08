import Foundation
import Network
import OSLog

extension WealthIBKRBridge {
    func handle(_ state: NWConnection.State, from sourceConnection: NWConnection) {
        guard connection === sourceConnection || state == .cancelled else { return }

        switch state {
        case .setup, .preparing:
            break

        case .waiting(let error):
            logger.error("TWS waiting: \(error.localizedDescription, privacy: .public)")

            if connection === sourceConnection {
                connection = nil
            }

            WealthLiveMarketDataStore.shared.noteDisconnected(error.localizedDescription)
            emit(.disconnected(error.localizedDescription))
            scheduleReconnect(reason: error.localizedDescription)

        case .ready:
            guard connection === sourceConnection else { return }

            reconnectAttempt = 0
            logger.log("TWS socket ready at \(self.desiredHost, privacy: .public):\(self.desiredPort, privacy: .public)")

            emit(.connecting)
            sendGreeting()
            receiveData()

        case .failed(let error):
            if connection === sourceConnection {
                connection = nil
            }

            logger.error("TWS failed: \(error.localizedDescription, privacy: .public)")
            WealthLiveMarketDataStore.shared.noteFailed(error.localizedDescription)
            emit(.failed(error.localizedDescription))
            scheduleReconnect(reason: error.localizedDescription)

        case .cancelled:
            guard connection === sourceConnection || connection == nil else { return }

            if connection === sourceConnection {
                connection = nil
            }

            contractValidationRequests.values.forEach {
                $0.timeoutTask?.cancel()
                $0.continuation?.resume(returning: nil)
            }
            contractValidationRequests.removeAll()
            validatingKeys.removeAll()

            subscriptions.removeAll()
            requestIDToKey.removeAll()
            requestIDToContract.removeAll()
            partialQuotes.removeAll()

            snapshotRequestIDs.removeAll()
            snapshotCleanupTasks.values.forEach { $0.cancel() }
            snapshotCleanupTasks.removeAll()

            WealthLiveMarketDataStore.shared.noteDisconnected(cancelReason)

            if silentCancel {
                silentCancel = false
            } else {
                emit(.disconnected(cancelReason))
                scheduleReconnect(reason: cancelReason)
            }

        @unknown default:
            let message = "Unknown TWS connection state."
            WealthLiveMarketDataStore.shared.noteFailed(message)
            emit(.failed(message))
        }
    }

    func resubscribeAllContracts() {
        let existingContracts = Array(desiredSubscriptions.values)

        subscriptions.removeAll()
        requestIDToKey.removeAll()
        requestIDToContract.removeAll()
        partialQuotes.removeAll()

        snapshotRequestIDs.removeAll()
        snapshotCleanupTasks.values.forEach { $0.cancel() }
        snapshotCleanupTasks.removeAll()

        subscribe(to: existingContracts, delayedQuotes: delayedQuotesEnabled)
    }
}
