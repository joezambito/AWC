import SwiftUI

extension MarketsView {
    var phoneMarketPageSize: Int {
        18
    }

    var phoneLargeMarketThreshold: Int {
        500
    }

    var phoneMarketPriorityOrder: [String] {
        ["USA", "AU", "UK", "CA", "JP", "DE", "FR", "HK", "SG", "NZ"]
    }

    var phoneAllWorldShareRecords: [MarketUniverseRecord] {
        quoteableWorldShareRecords
    }

    var phoneRecordLookup: [String: MarketUniverseRecord] {
        phoneAllWorldShareRecords.reduce(into: [String: MarketUniverseRecord]()) { partialResult, record in
            partialResult[record.id] = record
        }
    }

    var phoneOpportunityLookup: [String: Opportunity] {
        engine.rankedAssets.reduce(into: [String: Opportunity]()) { partialResult, opportunity in
            let key = WealthOpportunityLaneRules.laneKey(symbol: opportunity.symbol, market: opportunity.market)
            partialResult[key] = opportunity
        }
    }

    var phoneMarketSummaries: [PhoneMarketSummary] {
        let grouped = Dictionary(grouping: phoneAllWorldShareRecords, by: phoneMarketCode(for:))

        return grouped
            .map { marketCode, records in
                PhoneMarketSummary(
                    code: marketCode,
                    count: records.count,
                    style: phoneBucketStyle(for: marketCode, count: records.count)
                )
            }
            .sorted { lhs, rhs in
                let leftPriority = phoneMarketPriorityOrder.firstIndex(of: lhs.code) ?? Int.max
                let rightPriority = phoneMarketPriorityOrder.firstIndex(of: rhs.code) ?? Int.max

                if leftPriority != rightPriority {
                    return leftPriority < rightPriority
                }

                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }

                return lhs.code < rhs.code
            }
    }

    var selectedPhoneMarketSummary: PhoneMarketSummary? {
        phoneMarketSummaries.first { $0.code == selectedPhoneMarketCode } ?? phoneMarketSummaries.first
    }

    var selectedPhoneMarketBuckets: [PhoneMarketLetterBucket] {
        guard let summary = selectedPhoneMarketSummary else { return [] }
        let includesOther = phoneAllWorldShareRecords.contains {
            phoneMarketCode(for: $0) == summary.code && !$0.symbol.uppercased().contains { $0.isLetter }
        }
        return PhoneMarketLetterBucket.buckets(for: summary.style, includeOther: includesOther)
    }

    var selectedPhoneLetterBucketDefinition: PhoneMarketLetterBucket? {
        selectedPhoneMarketBuckets.first { $0.id == selectedPhoneMarketLetterBucket } ?? selectedPhoneMarketBuckets.first
    }

    var selectedPhoneBucketCacheKey: String {
        "\(selectedPhoneMarketCode)|\(selectedPhoneMarketLetterBucket)"
    }

    var selectedPhoneBucketTotalCount: Int {
        guard let bucket = selectedPhoneLetterBucketDefinition else { return 0 }
        return phoneMarketBucketIDCache[selectedPhoneMarketCode]?[bucket.id]?.count ?? 0
    }

    var selectedPhoneBucketPageCount: Int {
        max(1, Int(ceil(Double(selectedPhoneBucketTotalCount) / Double(phoneMarketPageSize))))
    }

    var selectedPhoneBucketPage: Int {
        min(phoneMarketBucketPages[selectedPhoneBucketCacheKey, default: 0], max(0, selectedPhoneBucketPageCount - 1))
    }

    var phoneVisibleSubscriptionRecords: [MarketUniverseRecord] {
        selectedPhoneVisibleRecords
    }

    var selectedPhoneVisibleRecords: [MarketUniverseRecord] {
        guard let bucket = selectedPhoneLetterBucketDefinition else { return [] }
        let ids = phoneMarketBucketIDCache[selectedPhoneMarketCode]?[bucket.id] ?? []
        let start = selectedPhoneBucketPage * phoneMarketPageSize
        let end = min(start + phoneMarketPageSize, ids.count)

        guard start < end else { return [] }

        return ids[start..<end].compactMap { phoneRecordLookup[$0] }
    }

    var selectedPhoneVisibleEntries: [MarketUniverseEntry] {
        selectedPhoneVisibleRecords.map(phoneMarketEntry(for:))
    }

    func refreshPhoneAlphabetBlockCache() {
        guard !hasDesktopLayout else { return }

        let groupedRecords = Dictionary(grouping: phoneAllWorldShareRecords, by: phoneMarketCode(for:))
        let summaries = phoneMarketSummaries
        var nextCache: [String: [String: [String]]] = [:]

        for summary in summaries {
            let records = groupedRecords[summary.code, default: []]
            let buckets = PhoneMarketLetterBucket.buckets(
                for: summary.style,
                includeOther: records.contains { !$0.symbol.uppercased().contains { $0.isLetter } }
            )

            nextCache[summary.code] = buckets.reduce(into: [:]) { partial, bucket in
                partial[bucket.id] = records
                    .filter { bucket.matches(symbol: $0.symbol) }
                    .map(\.id)
            }
        }

        if nextCache[selectedPhoneMarketCode] == nil, let firstMarket = summaries.first {
            selectedPhoneMarketCode = firstMarket.code
        }

        let activeMarket = selectedPhoneMarketSummary?.code ?? selectedPhoneMarketCode
        let bucketIDs = nextCache[activeMarket] ?? [:]

        if bucketIDs[selectedPhoneMarketLetterBucket]?.isEmpty != false,
           let nextBucket = selectedPhoneMarketBuckets.first(where: { bucketIDs[$0.id]?.isEmpty == false }) {
            selectedPhoneMarketLetterBucket = nextBucket.id
        }

        phoneMarketBucketPages = phoneMarketBucketPages.filter { key, _ in
            let pieces = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else { return false }
            return nextCache[pieces[0]]?[pieces[1]] != nil
        }

        phoneMarketBucketIDCache = nextCache

        phoneMarketBucketPages[selectedPhoneBucketCacheKey] = min(
            phoneMarketBucketPages[selectedPhoneBucketCacheKey, default: 0],
            max(0, selectedPhoneBucketPageCount - 1)
        )
    }

    func phoneMarketCode(for record: MarketUniverseRecord) -> String {
        switch record.country.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "UNITED STATES", "USA", "US":
            return "USA"
        case "AUSTRALIA", "AU":
            return "AU"
        case "UNITED KINGDOM", "UK", "GB", "GREAT BRITAIN":
            return "UK"
        case "CANADA", "CA":
            return "CA"
        case "JAPAN", "JP":
            return "JP"
        case "GERMANY", "DE":
            return "DE"
        case "FRANCE", "FR":
            return "FR"
        case "HONG KONG", "HK":
            return "HK"
        case "SINGAPORE", "SG":
            return "SG"
        case "NEW ZEALAND", "NZ":
            return "NZ"
        default:
            let trimmed = record.country.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 2 {
                return String(trimmed.prefix(3)).uppercased()
            }
            return record.regionCode
        }
    }

    func phoneBucketStyle(for marketCode: String, count: Int) -> PhoneMarketBucketStyle {
        if marketCode == "USA" || count >= phoneLargeMarketThreshold {
            return .singleLetter
        }
        return .grouped
    }

    func selectPhoneMarket(_ marketCode: String) {
        selectedPhoneMarketCode = marketCode
        if let firstBucket = selectedPhoneMarketBuckets.first {
            selectedPhoneMarketLetterBucket = firstBucket.id
        }
        phoneMarketBucketPages["\(marketCode)|\(selectedPhoneMarketLetterBucket)"] = 0
    }

    func selectPhoneLetterBucket(_ bucketID: String) {
        selectedPhoneMarketLetterBucket = bucketID
        phoneMarketBucketPages[selectedPhoneBucketCacheKey] = 0
    }
}
