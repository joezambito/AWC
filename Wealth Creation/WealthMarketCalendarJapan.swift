import Foundation

extension WealthMarketCalendar {
    static func japanSchedule(for market: String, region: WealthMarketRegion) -> WealthMarketSchedule? {
        guard region == .japan else { return nil }

        return makeSchedule(
            timeZoneID: "Asia/Tokyo",
            tradable: [minutes(9, 0)..<minutes(11, 30), minutes(12, 30)..<minutes(15, 0)],
            holidays: ["2026-01-01", "2026-01-02", "2026-01-12", "2026-02-11", "2026-02-23", "2026-03-20", "2026-04-29", "2026-05-04", "2026-05-05", "2026-05-06", "2026-07-20", "2026-08-11", "2026-09-21", "2026-09-22", "2026-09-23", "2026-10-12", "2026-11-03", "2026-11-23", "2026-12-31"]
        )
    }
}
