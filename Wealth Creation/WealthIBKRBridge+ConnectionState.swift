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
            WealthLiveMarketDataStore.shared.noteFailed(error.localizedDescription)
            emit(.failed(error.localizedDescription))
            scheduleReconnect(reason: error.localizedDescription)
        case .ready:
            reconnectAttempt = 0
            WealthLiveMarketDataStore.shared.noteConnected(
                host: self.desiredHost,
                port: self.desiredPort,
                clientID: self.clientID
            )
            logger.log("TWS socket ready at \(self.desiredHost, privacy: .public):\(self.desiredPort, privacy: .public)")
            sendGreeting()
            receiveData()
        case .failed(let error):
            connection = nil
            logger.error("TWS failed: \(error.localizedDescription, privacy: .public)")
            WealthLiveMarketDataStore.shared.noteFailed(error.localizedDescription)
            emit(.failed(error.localizedDescription))
            scheduleReconnect(reason: error.localizedDescription)
        case .cancelled:
            guard connection === sourceConnection || connection == nil else { return }
            connection = nil
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
            WealthLiveMarketDataStore.shared.noteFailed("Unknown TWS connection state.")
            emit(.failed("Unknown TWS connection state."))
        }
    }

    func resubscribeAllContracts() {
        let existingContracts = subscriptions.values.map(\.contract)
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
