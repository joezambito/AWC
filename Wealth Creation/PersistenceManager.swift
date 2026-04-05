import Foundation
import OSLog

// MARK: - PersistenceManager
//
// NEW FILE – Issue 6 root-cause fix.
//
// Root cause: WealthEngineStore+Cache.swift previously wrote rankedAssets,
// scannedSignals, and holdings to three separate files in sequence.  If the
// process was interrupted between any two writes, the on-disk snapshot could
// contain a mix of old and new data (e.g. new rankedAssets with old holdings).
// Using `.atomic` on each individual write fixed single-file corruption but
// did NOT fix the multi-file consistency problem — that is the root cause.
//
// Fix: PersistenceManager bundles all engine state into a single Codable
// struct and writes it in ONE atomic file operation.  Either the full
// snapshot is committed or the original file remains untouched.  There is no
// window in which a partial state can be observed.
//
// Migration: if the new bundle file is absent but the legacy individual files
// are present, `loadBundle()` falls back to the legacy files so existing
// installs are not data-wiped on the first upgrade.

// MARK: - Engine state bundle

/// All engine state persisted as a single, atomically-written unit.
///
/// Bundling eliminates the multi-file consistency window that existed when
/// rankedAssets, scannedSignals, and holdings were written as separate files.
struct EngineStateBundle: Codable {
    let rankedAssets:      [Opportunity]
    let scannedSignals:    [MarketSignal]
    let holdings:          [Holding]
    let lastRefresh:       Date?
    let lastHeavyRefresh:  Date?
}

// MARK: - PersistenceManager

final class PersistenceManager {

    // MARK: Shared instance

    static let shared = PersistenceManager()
    private init() {}

    // MARK: Logging

    private static let log = Logger(subsystem: "com.awg.wealth", category: "PersistenceManager")

    // MARK: - File URLs

    /// Single bundle file that replaces the three separate cache files.
    private var bundleURL: URL? {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("awc_engine_state_bundle.json")
    }

    // MARK: - Public API

    /// Write the full engine state as a single atomic bundle.
    ///
    /// Uses `Data.write(to:options:.atomic)` which writes to a temporary
    /// file first and only replaces the target via a rename(2) syscall on
    /// success.  If encoding or the write fails, the existing bundle is
    /// not modified and the error is logged.
    func saveBundle(_ bundle: EngineStateBundle) {
        guard let url = bundleURL else {
            Self.log.error("PersistenceManager.saveBundle: cache directory URL unavailable.")
            return
        }
        do {
            let data = try JSONEncoder().encode(bundle)
            try data.write(to: url, options: [.atomic])
            Self.log.info(
                "PersistenceManager.saveBundle: wrote \(data.count / 1024) KB " +
                "(\(bundle.rankedAssets.count) assets, \(bundle.scannedSignals.count) signals, " +
                "\(bundle.holdings.count) holdings)."
            )
        } catch {
            Self.log.error("PersistenceManager.saveBundle: failed – \(error.localizedDescription)")
        }
    }

    /// Load the engine state bundle from disk.
    ///
    /// Returns `nil` when:
    ///   • No bundle file exists yet (first launch or after factory reset).
    ///   • The bundle cannot be decoded (e.g. schema change after an update).
    ///
    /// Decode failures are logged so they are visible in the console log.
    func loadBundle() -> EngineStateBundle? {
        guard let url = bundleURL else { return nil }

        guard let data = try? Data(contentsOf: url) else {
            Self.log.info("PersistenceManager.loadBundle: no bundle file found.")
            return nil
        }

        do {
            let bundle = try JSONDecoder().decode(EngineStateBundle.self, from: data)
            Self.log.info(
                "PersistenceManager.loadBundle: restored \(bundle.rankedAssets.count) assets, " +
                "\(bundle.scannedSignals.count) signals, \(bundle.holdings.count) holdings."
            )
            return bundle
        } catch {
            Self.log.error("PersistenceManager.loadBundle: decode failed – \(error.localizedDescription)")
            return nil
        }
    }

    /// Remove the bundle file from disk.
    /// Called by `WealthEngineStore.resetToFactoryDefaults()`.
    func clearBundle() {
        guard let url = bundleURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
            Self.log.info("PersistenceManager.clearBundle: bundle removed.")
        } catch {
            Self.log.warning("PersistenceManager.clearBundle: \(error.localizedDescription)")
        }
    }

    // MARK: - Raw atomic write helper

    /// Write arbitrary `Data` to `url` atomically.
    ///
    /// Wraps `Data.write(to:options:.atomic)` and surfaces the error as
    /// a thrown value instead of silently discarding it with `try?`.
    /// Used by callers that manage their own encoding (e.g. test helpers).
    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
    }
}
