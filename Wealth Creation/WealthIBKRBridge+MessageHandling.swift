import Foundation
import OSLog

extension WealthIBKRBridge {
    func handleTickPrice(_ fields: [String]) {
        guard
            let requestID = Int(fields[safe: 2] ?? ""),
            let tickType = Int(fields[safe: 3] ?? ""),
            let rawPrice = Double(fields[safe: 4] ?? ""),
            rawPrice > 0,
            let key = requestIDToKey[requestID]
        else {
            return
        }

        let contract = requestIDToContract[requestID] ?? subscriptions[key]?.contract
        var partial = partialQuotes[requestID] ?? PartialQuote(currency: contract?.currency ?? "USD")
        partial.timestamp = .now

        switch tickType {
        case 1, 66:
            partial.bid = rawPrice
            partial.isDelayed = tickType >= 66
        case 2, 67:
            partial.ask = rawPrice
            partial.isDelayed = tickType >= 66
        case 4, 68:
            partial.last = rawPrice
            partial.isDelayed = tickType >= 66
        case 9, 75:
            partial.close = rawPrice
            partial.isDelayed = tickType >= 66
        default:
            break
        }

        partialQuotes[requestID] = partial
        logger.log(
            "tickPrice requestId=\(requestID, privacy: .public) symbol=\(key.symbol, privacy: .public) market=\(key.market, privacy: .public) tickType=\(tickType, privacy: .public) price=\(rawPrice, privacy: .public) delayed=\(partial.isDelayed, privacy: .public)"
        )
        WealthLiveMarketDataStore.shared.noteTickPrice(
            key: key,
            requestID: requestID,
            contract: contract,
            tickType: tickType,
            timestamp: partial.timestamp
        )

        let resolvedPrice = partial.last ?? partial.close ?? partial.bid ?? partial.ask
        guard let price = resolvedPrice else { return }

        emit(
            .quote(
                WealthBrokerQuote(
                    key: key,
                    price: price,
                    close: partial.close,
                    bid: partial.bid,
                    ask: partial.ask,
                    bidSize: partial.bidSize,
                    askSize: partial.askSize,
                    lastSize: partial.lastSize,
                    currency: partial.currency,
                    timestamp: partial.timestamp,
                    isDelayed: partial.isDelayed
                )
            )
        )

        if snapshotRequestIDs.contains(requestID), partial.last != nil, partial.close != nil {
            cleanupSnapshotRequest(requestID)
        }
    }

    func handleTickSize(_ fields: [String]) {
        guard
            let requestID = Int(fields[safe: 2] ?? ""),
            let tickType = Int(fields[safe: 3] ?? ""),
            let rawSize = Int(fields[safe: 4] ?? ""),
            rawSize >= 0,
            let key = requestIDToKey[requestID]
        else {
            return
        }

        let contract = requestIDToContract[requestID] ?? subscriptions[key]?.contract
        var partial = partialQuotes[requestID] ?? PartialQuote(currency: contract?.currency ?? "USD")
        partial.timestamp = .now

        switch tickType {
        case 0, 69:
            partial.bidSize = rawSize
            partial.isDelayed = tickType >= 69
        case 3, 70:
            partial.askSize = rawSize
            partial.isDelayed = tickType >= 70
        case 5, 71:
            partial.lastSize = rawSize
            partial.isDelayed = tickType >= 71
        default:
            break
        }

        partialQuotes[requestID] = partial
        logger.log(
            "tickSize requestId=\(requestID, privacy: .public) symbol=\(key.symbol, privacy: .public) market=\(key.market, privacy: .public) tickType=\(tickType, privacy: .public) size=\(rawSize, privacy: .public) delayed=\(partial.isDelayed, privacy: .public)"
        )
        WealthLiveMarketDataStore.shared.noteTickSize(
            key: key,
            requestID: requestID,
            contract: contract,
            tickType: tickType,
            timestamp: partial.timestamp
        )
    }

    func handleError(_ fields: [String]) {
        let code = Int(fields[safe: 3] ?? "")
        let message = fields[safe: 4] ?? "Unknown TWS error."
        let requestID = Int(fields[safe: 2] ?? "")
        let key = requestID.flatMap { requestIDToKey[$0] }

        if let code, [2104, 2106, 2158].contains(code) {
            return
        }

        if let requestID, contractValidationRequests[requestID] != nil {
            logger.error("IB contractDetails error code=\(code ?? -1, privacy: .public) requestId=\(requestID, privacy: .public) message=\(message, privacy: .public)")
            WealthLiveMarketDataStore.shared.noteError(code: code, message: message, requestID: requestID, key: nil)
            finishContractValidation(requestID: requestID, resolvedContract: nil, reason: message)
            return
        }

        if let requestID {
            cleanupSnapshotRequest(requestID)
        }

        logger.error("IB error code=\(code ?? -1, privacy: .public) requestId=\(requestID ?? -1, privacy: .public) message=\(message, privacy: .public)")
        WealthLiveMarketDataStore.shared.noteError(code: code, message: message, requestID: requestID, key: key)

        if shouldRetryClientID(code: code, message: message) {
            if retryWithFreshClientIDIfNeeded(reason: message) {
                return
            }
        }

        if let code, [354, 10167].contains(code) {
            useDelayedFallback(reason: message)
        }
    }

    func handleMarketDataType(_ fields: [String]) {
        guard let reportedType = Int(fields[safe: 3] ?? "") else { return }
        logger.log("marketDataType callback=\(reportedType, privacy: .public)")
        WealthLiveMarketDataStore.shared.noteMarketDataType(reportedType)
    }

    func ingestHandshakeMessage(messageID: Int, fields: [String]) {
        if messageID == 9, let validID = Int(fields[safe: 2] ?? "") {
            nextRequestID = max(nextRequestID, validID)
            hasValidRequestID = true
            logger.log("IB handshake nextValidId=\(validID, privacy: .public)")
        } else if messageID == 15 {
            hasManagedAccounts = true
            logger.log("IB handshake managedAccounts received")
        }

        if hasValidRequestID && !apiReady {
            apiReady = true
            logger.log("IB handshake apiReady=true delayedQuotes=\(self.delayedQuotesEnabled, privacy: .public) fallbackDelayed=\(self.fallbackToDelayedSent, privacy: .public)")
            WealthLiveMarketDataStore.shared.noteConnected(
                host: self.desiredHost,
                port: self.desiredPort,
                clientID: self.clientID
            )
            emit(.connected)
            sendMarketDataType((delayedQuotesEnabled || fallbackToDelayedSent) ? 3 : 1)
            resubscribeAllContracts()
        }
    }

    private func shouldRetryClientID(code: Int?, message: String) -> Bool {
        if code == 326 { return true }

        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.contains("client id") || normalized.contains("clientid") else { return false }
        return normalized.contains("already") || normalized.contains("in use")
    }
}

extension WealthIBKRContract {
    func snapshotContract() -> WealthIBKRContract {
        WealthIBKRContract(
            key: key,
            symbol: symbol,
            secType: secType,
            exchange: exchange,
            primaryExchange: primaryExchange,
            currency: currency,
            localSymbol: localSymbol,
            tradingClass: tradingClass,
            genericTickList: genericTickList,
            snapshot: true,
            regulatorySnapshot: regulatorySnapshot
        )
    }
}
