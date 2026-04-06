import SwiftUI

extension MarketsView {
    private var phoneRegionBatchSizeByRegion: [String: Int] {
        [
            "US": 160,
            "AU": 90,
            "CA": 90,
            "EU": 140,
            "APAC": 140,
            "ME": 80,
            "LATAM": 80,
            "AFRICA": 70,
            "GLOBAL": 80,
            "UNKNOWN": 60
        ]
    }

    var importedMarketRecordsForCurrentBatch: [MarketUniverseRecord] {
        guard !hasDesktopLayout else { return importedMarketRecords }
        return batchedPhoneImportedMarketRecords()
    }

    private func batchedPhoneImportedMarketRecords() -> [MarketUniverseRecord] {
        var batchedRecords: [MarketUniverseRecord] = []
        let recordsByRegion = importedMarketRecordsByRegion

        for region in preferredRegionOrder {
            let regionRecords = (recordsByRegion[region] ?? [])
                .sorted { lhs, rhs in
                    MarketUniverseRecord.browserOrder(lhs: lhs, rhs: rhs)
                }

            guard !regionRecords.isEmpty else { continue }

            let batchSize = phoneRegionBatchSizeByRegion[region] ?? 60
            let batchCount = max(1, Int(ceil(Double(regionRecords.count) / Double(batchSize))))
            let batchIndex = marketFeedScanBatchIndex % batchCount
            let start = batchIndex * batchSize
            let end = min(start + batchSize, regionRecords.count)

            guard start < end else { continue }
            batchedRecords.append(contentsOf: regionRecords[start..<end])
        }

        for (region, regionRecords) in recordsByRegion where !preferredRegionOrder.contains(region) {
            let sortedRecords = regionRecords.sorted { lhs, rhs in
                MarketUniverseRecord.browserOrder(lhs: lhs, rhs: rhs)
            }
            let batchSize = phoneRegionBatchSizeByRegion[region] ?? 60
            let batchCount = max(1, Int(ceil(Double(sortedRecords.count) / Double(batchSize))))
            let batchIndex = marketFeedScanBatchIndex % batchCount
            let start = batchIndex * batchSize
            let end = min(start + batchSize, sortedRecords.count)

            guard start < end else { continue }
            batchedRecords.append(contentsOf: sortedRecords[start..<end])
        }

        return batchedRecords
    }
}
