import Foundation
import OSLog

// MARK: - Greeting & Handshake (Send Extension)

extension WealthIBKRBridge {

    private static let sendLog = Logger(subsystem: "com.awg.wealth", category: "IBKRBridge.Send")

    // MARK: - Greeting (Fixed)

    /// Sends the TWS API greeting in the correct format:
    ///   `API\0` + raw version-range string (no length prefix).
    ///
    /// TWS expects the greeting bytes to be exactly:
    ///   65 50 49 00  <version-range-bytes>
    ///
    /// The previous broken implementation wrapped the version range with
    /// `prefixed()`, which prepended a 4-byte big-endian length header.
    /// TWS does not expect that header during the initial handshake and
    /// immediately closes the connection when it encounters it.
    func sendGreeting() {
        let prefix = Data("API\0".utf8)
        let versionData = Data(self.negotiatedClientVersionRange.utf8)
        // Correct: raw bytes only — no prefixed() call
        let greeting = prefix + versionData

        logGreetingBytes(greeting)
        logHandshakeState("sendGreeting", detail: "Sending \(greeting.count) bytes: API\\0 + \(self.negotiatedClientVersionRange)")
        sendRaw(greeting)
    }

    // MARK: - Start API

    func sendStartAPI() {
        // Message ID 71 = START_API, version 2
        // Fields: msgID, version, clientId, optionalCapabilities
        logHandshakeState("sendStartAPI", detail: "Sending START_API (71) clientId=\(clientID)")
        send(["71", "2", "\(clientID)", ""])
    }

    // MARK: - Market Data

    func subscribeMarketData(contract: WealthIBKRContract) -> Int {
        // Issue 9: validate contract inputs before sending to TWS.
        guard !contract.symbol.trimmingCharacters(in: .whitespaces).isEmpty else {
            Self.sendLog.warning("IBKRBridge.subscribeMarketData: empty symbol — request skipped.")
            return -1
        }
        guard !contract.secType.trimmingCharacters(in: .whitespaces).isEmpty else {
            Self.sendLog.warning("IBKRBridge.subscribeMarketData: empty secType — request skipped.")
            return -1
        }
        let reqID = nextReqID()
        // Message ID 1 = REQ_MKT_DATA, version 11
        send([
            "1",
            "11",
            "\(reqID)",
            "\(contract.conId ?? 0)",
            contract.symbol,
            contract.secType,
            "",
            "0",
            "",
            "",
            contract.exchange,
            "",
            contract.currency,
            "",
            "",
            "0",
            "",
            "0",
            "0",
            ""
        ])
        return reqID
    }

    func cancelMarketData(requestID: Int) {
        // Message ID 2 = CANCEL_MKT_DATA, version 1
        send(["2", "1", "\(requestID)"])
    }
}

// MARK: - Diagnostic Helpers (NEW — no logic changes)

extension WealthIBKRBridge {

    private static let diagLog = Logger(subsystem: "com.awg.wealth", category: "IBKRBridge.Diag")

    /// Logs the exact bytes that will be sent as the greeting to aid debugging.
    /// Each byte is shown in hex and as a printable ASCII character.
    func logGreetingBytes(_ data: Data) {
        let hex = data.map { String(format: "%02x", $0) }.joined(separator: " ")
        let ascii = data.map { $0 >= 32 && $0 < 127 ? String(UnicodeScalar($0)) : "·" }.joined()
        Self.diagLog.debug("IBKRBridge greeting (\(data.count) bytes) HEX: \(hex)")
        Self.diagLog.debug("IBKRBridge greeting ASCII: \(ascii)")
    }

    /// Logs raw bytes received from TWS, capped at the first 64 bytes so the
    /// log line stays readable. Use this before and after the handshake to
    /// verify framing.
    func logReceivedBytes(_ data: Data, label: String) {
        let preview = data.prefix(64)
        let hex = preview.map { String(format: "%02x", $0) }.joined(separator: " ")
        Self.diagLog.debug("IBKRBridge recv[\(label)] \(data.count) bytes — HEX: \(hex)")
    }

    /// Records a named handshake step with an optional free-text detail.
    /// Call this at each state transition so the console log shows the exact
    /// sequence of events without requiring a debugger.
    func logHandshakeState(_ step: String, detail: String = "") {
        Self.diagLog.info("IBKRBridge handshake[\(step)]: \(detail)")
    }
}

// MARK: - Validation Helpers (NEW — no logic changes)

extension WealthIBKRBridge {

    private static let validLog = Logger(subsystem: "com.awg.wealth", category: "IBKRBridge.Validation")

    /// Validates that the server-version integer returned by TWS during
    /// handshake falls within the range supported by the app.
    /// Returns `true` if valid; logs a warning and returns `false` otherwise.
    @discardableResult
    func validateServerVersion(_ version: Int) -> Bool {
        let minSupported = 100
        let maxSupported = 999
        guard version >= minSupported && version <= maxSupported else {
            Self.validLog.warning(
                "IBKRBridge: serverVersion \(version) outside expected range [\(minSupported)..\(maxSupported)]"
            )
            return false
        }
        Self.validLog.info("IBKRBridge: serverVersion \(version) OK")
        return true
    }

    /// Validates that `data` starts with a valid 4-byte big-endian length
    /// prefix that is consistent with the total data size.
    /// Used to verify message framing after the handshake.
    @discardableResult
    func validateMessageFrame(_ data: Data) -> Bool {
        guard data.count >= 4 else {
            Self.validLog.warning(
                "IBKRBridge: frame too short (\(data.count) bytes) — need at least 4 for length prefix"
            )
            return false
        }
        let declared = Int(data[0]) << 24 | Int(data[1]) << 16 | Int(data[2]) << 8 | Int(data[3])
        let available = data.count - 4
        guard available >= declared else {
            Self.validLog.warning(
                "IBKRBridge: frame declares \(declared) bytes but only \(available) bytes are available"
            )
            return false
        }
        return true
    }

    /// Inspects a connection failure event and logs a human-readable hint
    /// about whether the root cause is likely a format issue, a network
    /// issue, or a credentials/configuration issue.
    /// Does not change any connection state.
    func diagnoseRejection(event: WealthIBKRBridgeEvent) {
        switch event {
        case .failed(let reason):
            if reason.contains("refused") || reason.contains("Connection refused") {
                Self.validLog.error(
                    "IBKRBridge diagnosis: TWS refused the connection — verify TWS is running, " +
                    "API connections are enabled in Global Configuration, and port 7497 is correct"
                )
            } else if reason.contains("timed out") || reason.contains("timeout") {
                Self.validLog.error(
                    "IBKRBridge diagnosis: connection timed out — check LAN route to TWS host (\(AWCSecretConfig.shared.ibkrHost))"
                )
            } else if reason.contains("Send error") {
                Self.validLog.error(
                    "IBKRBridge diagnosis: send failed — greeting may have been sent before TCP was fully ready"
                )
            } else {
                Self.validLog.error("IBKRBridge diagnosis: unclassified failure — \(reason)")
            }
        case .disconnected(let reason):
            Self.validLog.warning(
                "IBKRBridge diagnosis: disconnected (\(reason)) — if during handshake, " +
                "TWS likely rejected greeting format or the client ID is already in use"
            )
        default:
            break
        }
    }

    /// Checks that `field` is non-empty and logs a warning if it is.
    /// Use this to verify individual fields in the TWS handshake response.
    @discardableResult
    func validateField(_ field: String, name: String) -> Bool {
        guard !field.isEmpty else {
            Self.validLog.warning("IBKRBridge: field '\(name)' is empty — handshake response may be malformed")
            return false
        }
        return true
    }
}
