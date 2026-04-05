import Foundation

// MARK: - WealthMarketUniverseStartupCache
//
// File-backed snapshot cache for the market universe.  Used to restore the
// universe on launch without waiting for a full network download.
//
// Migration: `legacyDefaultsKey` was previously written into UserDefaults.
// If a file-based snapshot is present, the legacy key is removed during
// WealthMarketUniverseStore and WealthAppSessionController init.

enum WealthMarketUniverseStartupCache {

    // MARK: - Keys

    /// UserDefaults key written by the legacy (pre-file) snapshot path.
    static let legacyDefaultsKey = "awc_market_universe_snapshot"

    // MARK: - Snapshot model

    struct Snapshot: Codable {
        let records: [MarketUniverseRecord]
        let savedAt: Date
    }

    // MARK: - File URL

    static func snapshotFileURL() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("awc_universe_snapshot.json")
    }

    // MARK: - Persist

    static func save(_ snapshot: Snapshot) {
        guard let url = snapshotFileURL() else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Restore

    static func restore(defaults: UserDefaults) -> Snapshot? {
        // Prefer file-backed snapshot.
        if let url = snapshotFileURL(),
           let data = try? Data(contentsOf: url),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            return snapshot
        }
        // Legacy: UserDefaults path (migration).
        if let data = defaults.data(forKey: legacyDefaultsKey),
           let records = try? JSONDecoder().decode([MarketUniverseRecord].self, from: data) {
            return Snapshot(records: records, savedAt: .distantPast)
        }
        return nil
    }

    // MARK: - Validation

    static func isValidPersistedSnapshot(_ snapshot: Snapshot) -> Bool {
        !snapshot.records.isEmpty
    }
}
