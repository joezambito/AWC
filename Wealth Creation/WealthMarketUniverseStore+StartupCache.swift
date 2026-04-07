//
//  WealthMarketUniverseStore+StartupCache.swift
//  Wealth Creation
//
//  Universe Update 8/4/2026
//  Removed hardcoded 127,000–128,631 record count band.
//  The cache is now considered valid as long as it contains a reasonable
//  minimum number of records (25,000) and the region data is not entirely
//  blank.  The universe can grow to any size the device can hold without
//  the cache being thrown away.
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

enum WealthMarketUniverseStartupCache {
    static let snapshotVersion = 1
    static let snapshotFileName = "world_market_snapshot_v1.json"
    static let legacyDefaultsKey = "awc_world_market_snapshot_v1"

    // Minimum floor only – no upper cap.  Any count above this is accepted.
    static let fallbackReusableUniverseRecordCount = 25_000

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

    // A snapshot is valid when it has enough records and the region data
    // is not completely empty.  There is no upper cap – the universe is
    // free to grow as large as the device can store.
    static func isValidPersistedSnapshot(_ snapshot: WealthStoredUniverseSnapshot) -> Bool {
        guard snapshot.records.count >= fallbackReusableUniverseRecordCount else { return false }

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

    // A reload is required only when the record set is below the minimum
    // floor or the region data is entirely blank.  A larger-than-before
    // record count is not a reason to force a reload – it is handled by
    // the count-change detection in the store itself.
    static func requiresCanonicalReload(_ records: [MarketUniverseRecord]) -> Bool {
        guard !records.isEmpty else { return false }
        guard records.count >= fallbackReusableUniverseRecordCount else { return true }

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
