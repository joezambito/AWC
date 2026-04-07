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

    static func snapshotFileURL(
        fileManager: FileManager = .default
    ) -> URL? {
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }

        return appSupport
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

        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }

        if let url = snapshotFileURL(fileManager: fileManager) {
            let dir = url.deletingLastPathComponent()
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            try? encoded.write(to: url, options: .atomic)
        }

        defaults.removeObject(forKey: legacyDefaultsKey)
    }

    static func restore(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> WealthStoredUniverseSnapshot? {
        if let url = snapshotFileURL(fileManager: fileManager),
           let data = try? Data(contentsOf: url),
           let snapshot = try? JSONDecoder().decode(WealthStoredUniverseSnapshot.self, from: data) {
            return snapshot
        }

        guard
            let legacyData = defaults.data(forKey: legacyDefaultsKey),
            let snapshot = try? JSONDecoder().decode(WealthStoredUniverseSnapshot.self, from: legacyData)
        else { return nil }

        if let url = snapshotFileURL(fileManager: fileManager) {
            let dir = url.deletingLastPathComponent()
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            try? legacyData.write(to: url, options: .atomic)
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

        let low = min(canonicalUniverseRecordCount, minimumReusableUniverseRecordCount)
        let high = max(canonicalUniverseRecordCount, maximumReusableUniverseRecordCount)

        guard snapshot.records.count >= low else { return false }
        guard snapshot.records.count <= high else { return false }

        let badCount = snapshot.records.filter { rec in
            let region = rec.region.trimmingCharacters(in: .whitespacesAndNewlines)
            let market = rec.market.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !["FX", "CRYPTO", "GLOBAL"].contains(market) else { return false }
            return region.isEmpty || region.caseInsensitiveCompare("unknown") == .orderedSame
        }.count

        return badCount != snapshot.records.count
    }

    static func requiresCanonicalReload(_ records: [MarketUniverseRecord]) -> Bool {
        guard !records.isEmpty else { return false }

        let low = min(canonicalUniverseRecordCount, minimumReusableUniverseRecordCount)
        let high = max(canonicalUniverseRecordCount, maximumReusableUniverseRecordCount)

        if records.count < low { return true }
        if records.count > high { return true }

        let badCount = records.filter { rec in
            let region = rec.region.trimmingCharacters(in: .whitespacesAndNewlines)
            let market = rec.market.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !["FX", "CRYPTO", "GLOBAL"].contains(market) else { return false }
            return region.isEmpty || region.caseInsensitiveCompare("unknown") == .orderedSame
        }.count

        return badCount == records.count
    }
}
