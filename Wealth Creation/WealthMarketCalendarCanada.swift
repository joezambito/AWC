import Foundation

extension WealthMarketCalendar {
    static func canadaSchedule(for market: String, region: WealthMarketRegion) -> WealthMarketSchedule? {
        guard region == .canada else { return nil }

        return makeSchedule(
            timeZoneID: "America/Toronto",
            tradable: [minutes(9, 30)..<minutes(16, 0)],
            afterHours: [minutes(7, 0)..<minutes(9, 30), minutes(16, 0)..<minutes(17, 0)],
            holidays: ["2026-01-01", "2026-02-16", "2026-04-03", "2026-05-18", "2026-07-01", "2026-08-03", "2026-09-07", "2026-10-12", "2026-12-25", "2026-12-28"],
            specialSessions: [
                "2026-12-24": ([minutes(9, 30)..<minutes(13, 0)], [minutes(7, 0)..<minutes(9, 30)])
            ]
        )
    }
}
