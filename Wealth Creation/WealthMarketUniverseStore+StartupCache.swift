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

enum WealthMarketUniverseStartupCache {
    static let snapshotVersion = 1
    static let snapshotFileName = "world_market_snapshot_v1.json"
    static let legacyDefaultsKey = "awc_world_market_snapshot_v1"
    static let canonicalUniverseRecordCount = 128_623
    static let minimumReusableUniverseRecordCount = 127_000
    static let fallbackReusableUniverseRecordCount = 25_000
    static let maximumReusableUniverseRecordCount = 128_623 + 8

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

    static func isValidPersistedSnapshot(_ snapshot: WealthStoredUniverseSnapshot) -> Bool {
        guard !snapshot.records.isEmpty else { return false }

        let minimumReusableCount = min(canonicalUniverseRecordCount, minimumReusableUniverseRecordCount)
        let maximumReusableCount = max(canonicalUniverseRecordCount, maximumReusableUniverseRecordCount)

        if snapshot.records.count < minimumReusableCount { return false }
        if snapshot.records.count > maximumReusableCount { return false }

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

    static func requiresCanonicalReload(_ records: [MarketUniverseRecord]) -> Bool {
        guard !records.isEmpty else { return false }

        let minimumReusableCount = min(canonicalUniverseRecordCount, minimumReusableUniverseRecordCount)
        let maximumReusableCount = max(canonicalUniverseRecordCount, maximumReusableUniverseRecordCount)

        if records.count < minimumReusableCount { return true }
        if records.count > maximumReusableCount { return true }

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
