import Foundation
import OSLog

// MARK: - AWCSecretConfig
//
// NEW FILE – Issue 8 root-cause fix.
//
// Root cause: IBKR clientID (77), TWS host reference, and other connection
// parameters were literal values embedded in source files
// (WealthIBKRBridge.swift).  Hardcoded credentials cannot be rotated
// without recompiling the app and commit them to source history, which is a
// security risk.
//
// Fix: AWCSecretConfig reads key-value pairs from a plain-text .env file
// located at:
//
//   <Documents>/awc.env
//
// Expected format (one KEY=value per line; # lines are comments):
//
//   IBKR_CLIENT_ID=77
//   IBKR_HOST=192.168.1.21
//   IBKR_PORT=7497
//   MARKET_DATA_BASE_URL=https://api.example.com
//
// The file is NEVER committed to source control — see .gitignore entry
// for awc.env.  AWCSecretConfig falls back to built-in defaults when the
// file is absent so the app does not crash at launch.
//
// Users must create Documents/awc.env on the device to override defaults.
// An example template is provided in .env.example at the repo root.

// MARK: - AWCSecretConfig

@MainActor
final class AWCSecretConfig {

    // MARK: - Shared instance

    static let shared = AWCSecretConfig()

    // MARK: - Logging

    private static let log = Logger(subsystem: "com.awg.wealth", category: "AWCSecretConfig")

    // MARK: - Private state

    private var values: [String: String] = [:]

    // MARK: - Init

    private init() {
        loadDotEnv()
    }

    // MARK: - Public config accessors

    /// IBKR TWS client ID used in the START_API handshake.
    /// Source: IBKR_CLIENT_ID in awc.env.  Default: 77.
    var ibkrClientID: Int {
        intValue(for: "IBKR_CLIENT_ID", default: 77)
    }

    /// IBKR TWS host address.
    /// Source: IBKR_HOST in awc.env.  Default: empty string (bridge will
    /// refuse to connect until a host is configured).
    var ibkrHost: String {
        stringValue(for: "IBKR_HOST", default: "")
    }

    /// IBKR TWS port number.
    /// Source: IBKR_PORT in awc.env.  Default: 7497 (standard TWS paper
    /// trading port).
    var ibkrPort: UInt16 {
        UInt16(clamping: intValue(for: "IBKR_PORT", default: 7497))
    }

    /// Base URL for the market data REST API used by MarketDataFetcher.
    /// Source: MARKET_DATA_BASE_URL in awc.env.  Default: empty string.
    var marketDataBaseURL: String {
        stringValue(for: "MARKET_DATA_BASE_URL", default: "")
    }

    // MARK: - Loader

    /// Read key-value pairs from `<Documents>/awc.env`.
    ///
    /// Called once in `init()`.  Idempotent if called again.
    func loadDotEnv() {
        guard values.isEmpty else { return }

        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Self.log.warning("AWCSecretConfig: Documents directory not found; using built-in defaults.")
            return
        }

        let envURL = docs.appendingPathComponent("awc.env")

        guard fm.fileExists(atPath: envURL.path) else {
            Self.log.warning(
                "AWCSecretConfig: awc.env not found at \(envURL.path). " +
                "Using built-in defaults. " +
                "Create Documents/awc.env with IBKR_CLIENT_ID, IBKR_HOST, " +
                "IBKR_PORT, MARKET_DATA_BASE_URL to override."
            )
            return
        }

        guard let content = try? String(contentsOf: envURL, encoding: .utf8) else {
            Self.log.error("AWCSecretConfig: failed to read awc.env – using built-in defaults.")
            return
        }

        var loaded = 0
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key   = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            values[key] = value
            loaded += 1
        }

        Self.log.info("AWCSecretConfig: loaded \(loaded) key(s) from awc.env.")
    }

    // MARK: - Private helpers

    private func stringValue(for key: String, default fallback: String) -> String {
        values[key] ?? fallback
    }

    private func intValue(for key: String, default fallback: Int) -> Int {
        guard let raw = values[key], let parsed = Int(raw) else { return fallback }
        return parsed
    }
}
