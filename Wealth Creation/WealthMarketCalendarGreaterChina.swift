import Foundation

extension WealthMarketCalendar {
    static func greaterChinaSchedule(for market: String, region: WealthMarketRegion) -> WealthMarketSchedule? {
        guard region == .greaterChina else { return nil }

        switch market {
        case "HKEX":
            return makeSchedule(
                timeZoneID: "Asia/Hong_Kong",
                tradable: [minutes(9, 30)..<minutes(12, 0), minutes(13, 0)..<minutes(16, 0)],
                holidays: ["2026-01-01", "2026-02-17", "2026-02-18", "2026-02-19", "2026-04-03", "2026-04-06", "2026-04-07", "2026-05-01", "2026-05-25", "2026-06-19", "2026-07-01", "2026-09-26", "2026-10-01", "2026-10-19", "2026-12-25"],
                specialSessions: [
                    "2026-02-16": ([minutes(9, 30)..<minutes(12, 0)], []),
                    "2026-12-24": ([minutes(9, 30)..<minutes(12, 0)], [])
                ]
            )
        case "SSE", "SZSE":
            return makeSchedule(
                timeZoneID: "Asia/Hong_Kong",
                tradable: [minutes(9, 30)..<minutes(11, 30), minutes(13, 0)..<minutes(15, 0)],
                holidays: ["2026-01-01", "2026-02-17", "2026-02-18", "2026-02-19", "2026-04-03", "2026-04-06", "2026-04-07", "2026-05-01", "2026-05-25", "2026-06-19", "2026-07-01", "2026-09-26", "2026-10-01", "2026-10-19", "2026-12-25"]
            )
        default:
            return nil
        }
    }
}
