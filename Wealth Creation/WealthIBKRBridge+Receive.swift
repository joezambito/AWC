import Foundation
import Network

extension WealthIBKRBridge {
    func receiveData() {
        guard let connection else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 32_768) { [weak self] data, _, isComplete, error in
            guard let bridge = self else { return }
            Task { @MainActor in
                bridge.handleReceiveChunk(data: data, isComplete: isComplete, error: error)
            }
        }
    }

    func processReceiveBuffer() {
        while receiveBuffer.count >= 4 {
            let messageLength = receiveBuffer.prefix(4).reduce(0) { ($0 << 8) + UInt32($1) }
            let totalLength = 4 + Int(messageLength)
            guard receiveBuffer.count >= totalLength else { return }

            let payload = receiveBuffer[4..<totalLength]
            receiveBuffer.removeFirst(totalLength)

            let fields = payload
                .split(separator: 0, omittingEmptySubsequences: false)
                .map { String(decoding: $0, as: UTF8.self) }

            handleMessage(fields)
        }
    }

    func handleMessage(_ rawFields: [String]) {
        guard !rawFields.isEmpty else { return }

        let fields = rawFields.last == "" ? Array(rawFields.dropLast()) : rawFields

        if !apiReady, !hasValidRequestID, !hasManagedAccounts, fields.count == 2, let serverVersion = Int(fields[0]), serverVersion >= 157 {
            sendStartAPI()
            return
        }

        guard let messageID = Int(fields[0]) else { return }

        if !apiReady {
            ingestHandshakeMessage(messageID: messageID, fields: fields)
        }

        switch messageID {
        case 1:
            handleTickPrice(fields)
        case 2:
            handleTickSize(fields)
        case 4:
            handleError(fields)
        case 10:
            handleContractDetails(fields)
        case 52:
            handleContractDetailsEnd(fields)
        case 58:
            handleMarketDataType(fields)
        default:
            break
        }
    }

    func handleReceiveChunk(data: Data?, isComplete: Bool, error: NWError?) {
        if let error {
            connection = nil
            WealthLiveMarketDataStore.shared.noteFailed(error.localizedDescription)
            emit(.failed(error.localizedDescription))
            scheduleReconnect(reason: error.localizedDescription)
            return
        }

        if let data, !data.isEmpty {
            receiveBuffer.append(data)
            processReceiveBuffer()
        }

        if isComplete {
            connection = nil
            WealthLiveMarketDataStore.shared.noteDisconnected("TWS closed the connection.")
            emit(.disconnected("TWS closed the connection."))
            scheduleReconnect(reason: "TWS closed the connection.")
            return
        }

        receiveData()
    }
}
