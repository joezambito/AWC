//
//  WealthMarketUniverseStore+StartupCache.swift
//  Wealth Creation
//
//  Created by Joe Zambito on 2/4/2026.
//

import Foundation

struct WealthStoredUniverseSnapshot: Codable {
    let version: Int?
    let records: [MarketUniverseRecord]
    let sourceLabel: String
    let lastSuccessfulLoadAt: Date?
    let warningMessage: String?
    let errorMessage: String?
}

// Universe Update 8/4/2026: Removed fixed record-count bounds so the universe
// can grow freely beyond the original 128 623 ceiling. The cache is now accepted
// as valid whenever it is non-empty and structurally sound (valid region data).
// The phone will never re-download on launch if a valid cache already exists.
enum WealthMarketUniverseStartupCache {
    static let snapshotVersion = 1
    static let snapshotFileName = "world_market_snapshot_v1.json"
    static let legacyDefaultsKey = "awc_world_market_snapshot_v1"
    /// Kept for reference only — no longer used as a hard validation gate.
    static let canonicalUniverseRecordCount = 128_623
    /// Kept for reference only — no longer used as a hard validation gate.
    static let minimumReusableUniverseRecordCount = 1
    /// Kept for reference only — no longer used as a hard validation gate.
    static let fallbackReusableUniverseRecordCount = 25_000
    /// Kept for reference only — no longer used as a hard validation gate.
    static let maximumReusableUniverseRecordCount = Int.max

    static func snapshotFileURL(fileManager: FileManager = .default) -> URL? {
        guard let applicationSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        return applicationSupport
            .appendingPathComponent("WealthCreation", isDirectory: true)
            .appendingPathComponent(snapshotFileName)
    }

    static func persist(
        records: [MarketUniverseRecord],
        sourceLabel: String,
        lastSuccessfulLoadAt: Date?,
        warningMessage: String?,
        errorMessage: String?,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        let snapshot = WealthStoredUniverseSnapshot(
            version: snapshotVersion,
            records: records,
            sourceLabel: sourceLabel,
            lastSuccessfulLoadAt: lastSuccessfulLoadAt,
            warningMessage: warningMessage,
            errorMessage: errorMessage
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        if let cacheURL = snapshotFileURL(fileManager: fileManager) {
            try? fileManager.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try? data.write(to: cacheURL, options: .atomic)
        }

        defaults.removeObject(forKey: legacyDefaultsKey)
    }

    static func restore(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> WealthStoredUniverseSnapshot? {
        if let cacheURL = snapshotFileURL(fileManager: fileManager),
           let data = try? Data(contentsOf: cacheURL),
           let snapshot = try? JSONDecoder().decode(WealthStoredUniverseSnapshot.self, from: data) {
            return snapshot
        }

        guard let data = defaults.data(forKey: legacyDefaultsKey),
              let snapshot = try? JSONDecoder().decode(WealthStoredUniverseSnapshot.self, from: data) else {
            return nil
        }

        if let cacheURL = snapshotFileURL(fileManager: fileManager) {
            try? fileManager.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try? data.write(to: cacheURL, options: .atomic)
        }

        defaults.removeObject(forKey: legacyDefaultsKey)
        return snapshot
    }

    static func hasUsableFullSnapshot(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> Bool {
        guard let snapshot = restore(defaults: defaults, fileManager: fileManager) else {
            return false
        }

        return isValidPersistedSnapshot(snapshot)
    }

    // Universe Update 8/4/2026: Count-bound gates removed. Any non-empty snapshot
    // with structurally valid region data is accepted. The universe is free to grow
    // beyond the old 128 623 ceiling without ever being wrongly rejected on launch.
    static func isValidPersistedSnapshot(_ snapshot: WealthStoredUniverseSnapshot) -> Bool {
        guard !snapshot.records.isEmpty else { return false }

        let invalidRegionCount = snapshot.records.filter { record in
            let region = record.region.trimmingCharacters(in: .whitespacesAndNewlines)
            let market = record.market.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            if ["FX", "CRYPTO", "GLOBAL"].contains(market) {
                return false
            }

            return region.isEmpty || region.caseInsensitiveCompare("unknown") == .orderedSame
        }.count

        return invalidRegionCount != snapshot.records.count
    }

    // Universe Update 8/4/2026: Count-bound gates removed. A reload is only
    // required when the snapshot is structurally invalid (all regions unknown),
    // not because record count drifted outside the old fixed range.
    static func requiresCanonicalReload(_ records: [MarketUniverseRecord]) -> Bool {
        guard !records.isEmpty else { return false }

        let invalidRegionCount = records.filter { record in
            let region = record.region.trimmingCharacters(in: .whitespacesAndNewlines)
            let market = record.market.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            if ["FX", "CRYPTO", "GLOBAL"].contains(market) {
                return false
            }

            return region.isEmpty || region.caseInsensitiveCompare("unknown") == .orderedSame
        }.count

        return invalidRegionCount == records.count
    }
}
