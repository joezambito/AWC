import Foundation
import Network
import OSLog

extension WealthIBKRBridge {
    func sendGreeting() {
        sendRaw(Data("API\0".utf8) + prefixed(Data("v157..178".utf8)))
    }

    func sendStartAPI() {
        send(fields: ["71", "2", String(clientID), ""])
    }

    func sendMarketDataType(_ type: Int) {
        WealthLiveMarketDataStore.shared.noteMarketDataType(type)
        logger.log("reqMarketDataType(\(type, privacy: .public))")
        send(fields: ["59", "1", String(type)])
    }

    func sendMarketDataRequest(_ contract: WealthIBKRContract, requestID: Int) {
        WealthLiveMarketDataStore.shared.noteSubscription(contract: contract, requestID: requestID)
        logger.log(
            "reqMktData sent requestId=\(requestID, privacy: .public) symbol=\(contract.symbol, privacy: .public) exchange=\(contract.exchange, privacy: .public) currency=\(contract.currency, privacy: .public)"
        )
        send(
            fields: [
                "1",
                "11",
                String(requestID),
                "",
                contract.symbol,
                contract.secType,
                "",
                "",
                "",
                "",
                contract.exchange,
                contract.primaryExchange,
                contract.currency,
                contract.localSymbol,
                contract.tradingClass,
                "0",
                contract.genericTickList,
                contract.snapshot ? "1" : "0",
                contract.regulatorySnapshot ? "1" : "0",
                ""
            ]
        )
    }

    func sendContractDetailsRequest(_ contract: WealthIBKRContract, requestID: Int) {
        logger.log(
            "reqContractDetails sent requestId=\(requestID, privacy: .public) symbol=\(contract.symbol, privacy: .public) secType=\(contract.secType, privacy: .public) exchange=\(contract.exchange, privacy: .public)"
        )
        send(
            fields: [
                "9",
                "8",
                String(requestID),
                contract.symbol,
                contract.secType,
                "",
                "",
                "",
                "",
                contract.exchange,
                contract.primaryExchange,
                contract.currency,
                contract.localSymbol,
                contract.tradingClass,
                "0",
                "",
                ""
            ]
        )
    }

    func send(fields: [String]) {
        let body = fields.joined(separator: "\0") + "\0"
        sendRaw(prefixed(Data(body.utf8)))
    }

    func prefixed(_ payload: Data) -> Data {
        var length = UInt32(payload.count).bigEndian
        return Data(bytes: &length, count: MemoryLayout<UInt32>.size) + payload
    }

    func sendRaw(_ data: Data) {
        guard let connection else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }
}
