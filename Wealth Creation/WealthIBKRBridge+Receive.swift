import Foundation
import OSLog

// MARK: - TWS API incoming message-type constants
//
// Only the message types that the app currently handles are listed.
// Full TWS EClient message-ID reference: https://interactivebrokers.github.io/tws-api/

private enum TWSIncoming {

    // MARK: Message IDs

    /// Price tick for a market-data subscription (REQ_MKT_DATA response).
    static let tickPrice:   Int = 1
    /// Size tick for a market-data subscription.
    static let tickSize:    Int = 2
    /// Error or informational message from TWS.
    static let errMsg:      Int = 4
    /// First message from TWS after handshake; provides the next valid order ID.
    static let nextValidId: Int = 9

    // MARK: TICK_PRICE tick-type values (field index 3)

    static let bidPrice:   Int = 1
    static let askPrice:   Int = 2
    static let lastPrice:  Int = 4
    static let highPrice:  Int = 6
    static let lowPrice:   Int = 7
    static let closePrice: Int = 9
    static let openPrice:  Int = 14

    // MARK: TICK_SIZE tick-type values (field index 3)

    static let bidSize:    Int = 0
    static let askSize:    Int = 3
    static let lastSize:   Int = 5
    static let volume:     Int = 8
}

// MARK: - WealthIBKRBridge+Receive
//
// Parses null-delimited TWS API messages received after the handshake
// and emits typed WealthIBKRBridgeEvent values to registered handlers.
//
// Supported incoming messages:
//   TICK_PRICE  (1) – price ticks for active market-data subscriptions
//   TICK_SIZE   (2) – size / volume ticks
//   ERR_MSG     (4) – TWS error and informational messages
//   NEXT_VALID_ID (9) – initial valid order ID; used to sync the request counter
//
// Quote assembly:
//   Individual price ticks for a request ID are accumulated in
//   `WealthIBKRBridge.partialQuotes`.  A complete `WealthBrokerQuote` is
//   emitted as a `.quote` event as soon as bid, ask, and last are all known.

extension WealthIBKRBridge {

    private static let recvLog = Logger(subsystem: "com.awg.wealth", category: "IBKRBridge.Receive")

    // MARK: - Entry point

    /// Parse one length-prefixed TWS API message and dispatch it.
    ///
    /// Called by `handleApiMessage(data:)` for every complete frame that
    /// arrives after the handshake.  The `data` argument contains the
    /// message body **without** the 4-byte length prefix.
    func parseApiMessage(data: Data) {
        // TWS frames the body as a sequence of null-terminated UTF-8 strings.
        guard let raw = String(data: data, encoding: .utf8) else {
            Self.recvLog.warning("IBKRBridge: non-UTF8 message body (\(data.count) bytes) — skipped")
            return
        }

        // Split on NUL, dropping the trailing empty element that the final NUL creates.
        var fields = raw.split(separator: "\0", omittingEmptySubsequences: false).map(String.init)
        if fields.last == "" { fields.removeLast() }

        guard let typeStr = fields.first, let msgType = Int(typeStr) else {
            Self.recvLog.warning("IBKRBridge: unrecognised message (no integer type) — prefix: \(raw.prefix(80))")
            return
        }

        switch msgType {
        case TWSIncoming.tickPrice:
            handleTickPrice(fields: fields)
        case TWSIncoming.tickSize:
            handleTickSize(fields: fields)
        case TWSIncoming.errMsg:
            handleErrorMessage(fields: fields)
        case TWSIncoming.nextValidId:
            handleNextValidId(fields: fields)
        default:
            Self.recvLog.debug("IBKRBridge: ignoring message type \(msgType) (\(fields.count) fields)")
        }
    }

    // MARK: - TICK_PRICE (msg type 1)
    //
    // Field layout (TWS EClient ≥ v100):
    //   [0] "1"             – message type
    //   [1] version         – message version (determines which optional fields are present)
    //   [2] reqId           – market-data request this tick belongs to
    //   [3] tickType        – price field identifier (bid=1, ask=2, last=4, …)
    //   [4] price           – the price value; "0" when unavailable
    //   [5] canAutoExecute  – "1" if order can auto-execute at this price (v1+)
    //   [6] size            – associated size tick (bid/ask/last size; v2+)
    //   [7] attrMask        – tick attributes bitmask (v3+)

    private func handleTickPrice(fields: [String]) {
        guard fields.count >= 5,
              let reqId    = Int(fields[2]),
              let tickType = Int(fields[3]),
              let price    = Double(fields[4]),
              price > 0
        else { return }

        switch tickType {
        case TWSIncoming.bidPrice:
            partialQuotes[reqId, default: WealthPartialQuote()].bid = price
        case TWSIncoming.askPrice:
            partialQuotes[reqId, default: WealthPartialQuote()].ask = price
        case TWSIncoming.lastPrice:
            partialQuotes[reqId, default: WealthPartialQuote()].last = price
            // LAST typically arrives after BID and ASK in the initial snapshot;
            // try to emit a complete quote now.
            tryEmitQuote(for: reqId)
        default:
            break
        }
    }

    // MARK: - TICK_SIZE (msg type 2)
    //
    // Field layout:
    //   [0] "2"       – message type
    //   [1] version
    //   [2] reqId
    //   [3] tickType  – size field identifier (bidSize=0, askSize=3, lastSize=5, volume=8)
    //   [4] size      – the size / volume value

    private func handleTickSize(fields: [String]) {
        guard fields.count >= 5,
              let reqId    = Int(fields[2]),
              let tickType = Int(fields[3]),
              let size     = Int(fields[4])
        else { return }

        if tickType == TWSIncoming.volume {
            partialQuotes[reqId, default: WealthPartialQuote()].volume = size
        }
    }

    // MARK: - ERR_MSG (msg type 4)
    //
    // Field layout:
    //   [0] "4"       – message type
    //   [1] version   – always "2" in modern TWS
    //   [2] reqId     – -1 for system-level messages not tied to a request
    //   [3] errorCode – numeric TWS error / warning code
    //   [4] errorMsg  – human-readable description
    //   [5] advancedOrderRejectJson  (optional, newer TWS versions)
    //
    // Error-code ranges:
    //   2xxx – warnings (data issues, connectivity notices)
    //   1xxx – system messages (non-fatal)
    //   ≥ 1000 (non-2xxx) – fatal errors surfaced to callers via `.failed` event

    private func handleErrorMessage(fields: [String]) {
        let reqId     = fields.count > 2 ? (Int(fields[2]) ?? -1) : -1
        let errorCode = fields.count > 3 ? (Int(fields[3]) ?? 0)  : 0
        let errorMsg  = fields.count > 4 ? fields[4]              : "(no message)"

        if reqId == -1 {
            Self.recvLog.warning("IBKRBridge system message \(errorCode): \(errorMsg)")
        } else {
            Self.recvLog.error("IBKRBridge error reqId=\(reqId) code=\(errorCode): \(errorMsg)")
        }

        // TWS uses error codes 2100–2199 for advisory/connectivity warnings.
        // Only surface genuinely fatal errors (≥ 1000, outside the 2xxx warning
        // range) as `.failed` events so callers can react appropriately.
        let isFatalError = errorCode >= 1000 && (errorCode < 2000 || errorCode > 2999)
        if isFatalError {
            emit(.failed("TWS error \(errorCode): \(errorMsg)"))
        }
    }

    // MARK: - NEXT_VALID_ID (msg type 9)
    //
    // Field layout:
    //   [0] "9"      – message type
    //   [1] version
    //   [2] orderId  – next valid order ID that TWS will accept
    //
    // TWS sends this immediately after the START_API handshake.  We align
    // `nextRequestID` to be at least this value so our request IDs never
    // collide with order IDs.

    private func handleNextValidId(fields: [String]) {
        guard fields.count > 2, let orderId = Int(fields[2]) else { return }
        if orderId > nextRequestID {
            nextRequestID = orderId
        }
        Self.recvLog.info("IBKRBridge nextValidId=\(orderId), nextRequestID=\(self.nextRequestID)")
    }

    // MARK: - Quote completion

    /// Emit a `.quote` event for `reqId` if bid, ask, and last are all known.
    ///
    /// The partial state is **retained** after emission so that subsequent tick
    /// updates (e.g. bid or ask moves) can trigger a fresh quote emission.
    private func tryEmitQuote(for reqId: Int) {
        guard let partial = partialQuotes[reqId],
              partial.isComplete,
              let subscription = subscriptions[reqId]
        else { return }

        let quote = WealthBrokerQuote(
            symbol: subscription.contract.symbol,
            bid:    partial.bid,
            ask:    partial.ask,
            last:   partial.last,
            volume: partial.volume
        )

        emit(.quote(quote))

        Self.recvLog.debug(
            "IBKRBridge quote \(quote.symbol) bid=\(quote.bid) ask=\(quote.ask) last=\(quote.last) vol=\(quote.volume)"
        )
    }
}
