import Foundation

extension WealthMarketCalendar {
    static func australiaSchedule(for market: String, region: WealthMarketRegion) -> WealthMarketSchedule? {
        guard region == .australia else { return nil }

        switch market {
        case "ASX":
            return makeSchedule(
                timeZoneID: "Australia/Sydney",
                tradable: [minutes(10, 0)..<minutes(16, 0)],
                holidays: ["2026-01-01", "2026-01-26", "2026-04-03", "2026-04-06", "2026-04-27", "2026-06-08", "2026-12-25", "2026-12-28"]
            )
        case "NZX":
            return makeSchedule(
                timeZoneID: "Pacific/Auckland",
                tradable: [minutes(10, 0)..<minutes(16, 45)],
                holidays: ["2026-01-01", "2026-01-02", "2026-02-06", "2026-04-03", "2026-04-06", "2026-04-27", "2026-06-01", "2026-10-26", "2026-12-25", "2026-12-28"]
            )
        default:
            return nil
        }
    }
}
