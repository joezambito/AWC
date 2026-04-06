import Foundation
import OSLog

extension WealthIBKRBridge {
    func validatedContracts(from candidates: [WealthIBKRContract]) async -> [WealthIBKRContract] {
        var validated: [WealthIBKRContract] = []
        var seen: Set<WealthBrokerQuoteKey> = []

        for candidate in candidates {
            guard seen.insert(candidate.key).inserted else { continue }
            guard WealthIBKRContractValidationStore.shared.shouldRetry(candidate.key) else { continue }

            if let resolved = await resolveContractIfNeeded(candidate) {
                validated.append(resolved)
            }
        }

        return validated
    }

    func resolveContractIfNeeded(_ candidate: WealthIBKRContract) async -> WealthIBKRContract? {
        if let cached = WealthIBKRContractValidationStore.shared.resolvedContract(for: candidate.key) {
            return cached
        }

        guard WealthIBKRContractValidationStore.shared.shouldRetry(candidate.key) else {
            return nil
        }

        if validatingKeys.contains(candidate.key) {
            return nil
        }

        validatingKeys.insert(candidate.key)
        defer { validatingKeys.remove(candidate.key) }

        let requestID = nextRequestID
        nextRequestID += 1

        return await withCheckedContinuation { continuation in
            var request = ContractValidationRequest(
                candidate: candidate,
                continuation: continuation
            )
            request.timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                self?.finishContractValidation(
                    requestID: requestID,
                    resolvedContract: nil,
                    reason: "contractDetails timeout"
                )
            }
            contractValidationRequests[requestID] = request
            sendContractDetailsRequest(candidate, requestID: requestID)
        }
    }

    func handleContractDetails(_ fields: [String]) {
        guard
            let requestID = Int(fields[safe: 2] ?? ""),
            var request = contractValidationRequests[requestID]
        else {
            return
        }

        if let parsed = parseResolvedContract(from: fields, candidate: request.candidate) {
            request.matches.append(parsed)
            contractValidationRequests[requestID] = request
        }
    }

    func handleContractDetailsEnd(_ fields: [String]) {
        guard let requestID = Int(fields[safe: 2] ?? "") else { return }
        guard let request = contractValidationRequests[requestID] else { return }

        let resolved = chooseResolvedContract(from: request.matches, candidate: request.candidate)
        let reason: String
        if resolved == nil {
            reason = request.matches.isEmpty ? "no contractDetails returned" : "no valid common-stock contract"
        } else {
            reason = "contractDetails resolved"
        }

        finishContractValidation(requestID: requestID, resolvedContract: resolved, reason: reason)
    }

    func finishContractValidation(
        requestID: Int,
        resolvedContract: WealthIBKRContract?,
        reason: String
    ) {
        guard let request = contractValidationRequests.removeValue(forKey: requestID) else { return }
        request.timeoutTask?.cancel()

        if let resolvedContract {
            logger.log(
                "contractDetails resolved requestId=\(requestID, privacy: .public) symbol=\(resolvedContract.symbol, privacy: .public) primaryExchange=\(resolvedContract.primaryExchange, privacy: .public)"
            )
            WealthIBKRContractValidationStore.shared.noteResolvedContract(resolvedContract)
            request.continuation?.resume(returning: resolvedContract)
            return
        }

        logger.error(
            "contractDetails invalid requestId=\(requestID, privacy: .public) symbol=\(request.candidate.symbol, privacy: .public) reason=\(reason, privacy: .public)"
        )
        WealthIBKRContractValidationStore.shared.markInvalid(request.candidate.key)
        request.continuation?.resume(returning: nil)
    }

    private func parseResolvedContract(
        from fields: [String],
        candidate: WealthIBKRContract
    ) -> WealthIBKRContract? {
        let symbol = (fields[safe: 3] ?? candidate.symbol).uppercased()
        let secType = (fields[safe: 4] ?? candidate.secType).uppercased()
        let exchange = (fields[safe: 8] ?? candidate.exchange).uppercased()
        let currency = (fields[safe: 9] ?? candidate.currency).uppercased()
        let localSymbol = fields[safe: 10] ?? candidate.localSymbol
        let tradingClass = fields[safe: 12] ?? candidate.tradingClass
        let primaryExchange = (fields[safe: 22] ?? candidate.primaryExchange).uppercased()
        let stockType = normalizedStockType(from: fields)

        guard symbol == candidate.symbol.uppercased() else { return nil }
        guard secType == "STK" else { return nil }
        guard exchange == "SMART" || candidate.exchange == "SMART" else { return nil }
        guard !looksNonStandard(symbol: symbol, localSymbol: localSymbol, tradingClass: tradingClass, stockType: stockType) else {
            return nil
        }

        return WealthIBKRContract(
            key: candidate.key,
            symbol: symbol,
            secType: "STK",
            exchange: "SMART",
            primaryExchange: primaryExchange,
            currency: currency.isEmpty ? candidate.currency : currency,
            localSymbol: localSymbol,
            tradingClass: tradingClass
        )
    }

    private func chooseResolvedContract(
        from matches: [WealthIBKRContract],
        candidate: WealthIBKRContract
    ) -> WealthIBKRContract? {
        let filtered = matches.filter {
            $0.secType == "STK" &&
            $0.exchange == "SMART" &&
            !looksNonStandard(
                symbol: $0.symbol,
                localSymbol: $0.localSymbol,
                tradingClass: $0.tradingClass,
                stockType: ""
            )
        }

        guard !filtered.isEmpty else { return nil }

        let sorted = filtered.sorted { lhs, rhs in
            let leftScore = resolutionScore(for: lhs, candidate: candidate)
            let rightScore = resolutionScore(for: rhs, candidate: candidate)
            if leftScore != rightScore { return leftScore > rightScore }
            if lhs.primaryExchange != rhs.primaryExchange { return lhs.primaryExchange < rhs.primaryExchange }
            return lhs.currency < rhs.currency
        }

        guard let best = sorted.first else { return nil }
        let topScore = resolutionScore(for: best, candidate: candidate)
        let competing = sorted.dropFirst().contains {
            resolutionScore(for: $0, candidate: candidate) == topScore
        }
        return competing ? nil : best
    }

    private func resolutionScore(
        for contract: WealthIBKRContract,
        candidate: WealthIBKRContract
    ) -> Int {
        var score = 0
        if contract.symbol == candidate.symbol { score += 4 }
        if !candidate.primaryExchange.isEmpty, contract.primaryExchange == candidate.primaryExchange { score += 3 }
        if contract.currency == candidate.currency { score += 2 }
        if contract.tradingClass == candidate.tradingClass, !candidate.tradingClass.isEmpty { score += 1 }
        if contract.localSymbol == candidate.localSymbol, !candidate.localSymbol.isEmpty { score += 1 }
        return score
    }

    private func normalizedStockType(from fields: [String]) -> String {
        let candidates = [43, 44, 45, 46].compactMap { fields[safe: $0] }
        return candidates.joined(separator: " ").uppercased()
    }

    private func looksNonStandard(
        symbol: String,
        localSymbol: String,
        tradingClass: String,
        stockType: String
    ) -> Bool {
        let joined = [symbol, localSymbol, tradingClass, stockType]
            .joined(separator: " ")
            .uppercased()

        if joined.contains("WARRANT") || joined.contains("RIGHT") || joined.contains("UNIT") || joined.contains("PREFERRED") {
            return true
        }
        if joined.contains("-WT") || joined.contains(" WS") || joined.contains("-W ") || joined.contains("-P") {
            return true
        }
        if joined.contains("'U") || joined.contains("-U") {
            return true
        }
        return false
    }
}
