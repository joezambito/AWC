import Foundation
import OSLog

// MARK: - WealthIBKRBridge+Portfolio
//
// Issue 5: Network/integration errors were not surfaced when syncing
// portfolio data with IBKR.  `syncPortfolioWithIBKR()` is the designated
// call site for portfolio/position synchronisation via the TWS API.
//
// All failure paths record a user-visible entry to WealthEventLogStore
// so errors are surfaced to the app instead of being silently dropped.

extension WealthIBKRBridge {

    private static let portfolioLog = Logger(subsystem: "com.awg.wealth", category: "IBKRBridge.Portfolio")

    // MARK: - Portfolio sync

    /// Sync current portfolio positions from IBKR TWS.
    ///
    /// Issue 5: every failure path records a user-visible error to
    /// `WealthEventLogStore` so integration errors are never silently dropped.
    ///
    /// Preconditions checked before sending:
    ///   - The TCP connection must be established.
    ///   - The API handshake must be complete (`apiReady == true`).
    func syncPortfolioWithIBKR() {
        guard apiReady else {
            let detail = "Error: IBKR API not ready — portfolio sync skipped. Ensure TWS is running and the handshake has completed."
            Self.portfolioLog.error("syncPortfolioWithIBKR: \(detail)")
            WealthEventLogStore.shared.record(
                title: "Portfolio Sync",
                detail: detail,
                category: "ibkr",
                tintName: "red",
                timestamp: .now
            )
            return
        }

        // Request open positions from TWS.
        // Message ID 61 = REQ_POSITIONS, version 1 (no fields beyond header).
        send(["61", "1"])
        Self.portfolioLog.info("syncPortfolioWithIBKR: REQ_POSITIONS sent (clientId=\(self.clientID))")
        WealthEventLogStore.shared.record(
            title: "Portfolio Sync",
            detail: "REQ_POSITIONS sent to IBKR (clientId=\(clientID)).",
            category: "ibkr",
            tintName: "blue",
            timestamp: .now
        )
    }
}
