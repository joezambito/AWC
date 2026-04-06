import Foundation
import Network
import OSLog

extension WealthIBKRBridge {
    private var handshakeLogPrefix: String { "IB handshake" }

    private var handshakeRejectedMessage: String {
        "TWS reset the API handshake before sending serverVersion. Check TWS API socket access, trusted IP settings, and the selected port."
    }

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

            let bufferStart = receiveBuffer.startIndex
            let payloadStart = receiveBuffer.index(bufferStart, offsetBy: 4)
            let payloadEnd = receiveBuffer.index(bufferStart, offsetBy: totalLength)
            let payload = Data(receiveBuffer[payloadStart..<payloadEnd])
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

        if !apiReady {
            let preview = fields.prefix(4).joined(separator: "|")
            logger.log("\(self.handshakeLogPrefix, privacy: .public) message fields=\(fields.count, privacy: .public) preview=\(preview, privacy: .public)")
        }

        if !apiReady, !hasValidRequestID, !hasManagedAccounts, fields.count == 2, let serverVersion = Int(fields[0]), serverVersion >= 100 {
            logger.log("\(self.handshakeLogPrefix, privacy: .public) serverVersion=\(serverVersion, privacy: .public) connectionTime=\(fields[1], privacy: .public)")
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
            logger.error("\(self.handshakeLogPrefix, privacy: .public) receive error=\(error.localizedDescription, privacy: .public)")
            connection = nil
            let failureMessage: String
            if !apiReady && !receivedServerHandshakeBytes {
                failureMessage = handshakeRejectedMessage
            } else {
                failureMessage = error.localizedDescription
            }
            WealthLiveMarketDataStore.shared.noteFailed(failureMessage)
            emit(.failed(failureMessage))
            scheduleReconnect(reason: failureMessage)
            return
        }

        if let data, !data.isEmpty {
            if !apiReady {
                receivedServerHandshakeBytes = true
                logger.log("\(self.handshakeLogPrefix, privacy: .public) received bytes=\(data.count, privacy: .public) complete=\(isComplete, privacy: .public)")
            }
            receiveBuffer.append(data)
            processReceiveBuffer()
        }

        if isComplete {
            logger.error("\(self.handshakeLogPrefix, privacy: .public) peer closed connection before apiReady=\((!self.apiReady), privacy: .public)")
            connection = nil
            let disconnectMessage: String
            if !apiReady && !receivedServerHandshakeBytes {
                disconnectMessage = handshakeRejectedMessage
            } else {
                disconnectMessage = "TWS closed the connection."
            }
            WealthLiveMarketDataStore.shared.noteDisconnected(disconnectMessage)
            emit(.disconnected(disconnectMessage))
            scheduleReconnect(reason: disconnectMessage)
            return
        }

        receiveData()
    }
}
