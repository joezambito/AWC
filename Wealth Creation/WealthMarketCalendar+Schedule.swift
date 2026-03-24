import Foundation

extension WealthMarketCalendar {
    static func schedule(for market: String) -> WealthMarketSchedule {
        let canonicalMarket = canonicalMarket(for: market)
        let marketRegion = region(for: canonicalMarket)

        if let schedule = usSchedule(for: canonicalMarket, region: marketRegion) { return schedule }
        if let schedule = canadaSchedule(for: canonicalMarket, region: marketRegion) { return schedule }
        if let schedule = europeSchedule(for: canonicalMarket, region: marketRegion) { return schedule }
        if let schedule = australiaSchedule(for: canonicalMarket, region: marketRegion) { return schedule }
        if let schedule = japanSchedule(for: canonicalMarket, region: marketRegion) { return schedule }
        if let schedule = greaterChinaSchedule(for: canonicalMarket, region: marketRegion) { return schedule }
        if let schedule = asiaSchedule(for: canonicalMarket, region: marketRegion) { return schedule }
        if let schedule = middleEastAfricaSchedule(for: canonicalMarket, region: marketRegion) { return schedule }
        if let schedule = latinAmericaSchedule(for: canonicalMarket, region: marketRegion) { return schedule }

        return fallbackSchedule()
    }
}
