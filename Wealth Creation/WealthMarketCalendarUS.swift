import Foundation

extension WealthMarketCalendar {
    static func usSchedule(for market: String, region: WealthMarketRegion) -> WealthMarketSchedule? {
        guard region == .us else { return nil }

        switch market {
        case "NASDAQ", "NYSE", "AMEX", "ETF", "REIT", "ADR", "OTC", "CBOE":
            return makeSchedule(
                timeZoneID: "America/New_York",
                tradable: [minutes(9, 30)..<minutes(16, 0)],
                afterHours: [minutes(4, 0)..<minutes(9, 30), minutes(16, 0)..<minutes(20, 0)],
                holidays: ["2026-01-01", "2026-01-19", "2026-02-16", "2026-04-03", "2026-05-25", "2026-06-19", "2026-07-03", "2026-09-07", "2026-11-26", "2026-12-25"],
                specialSessions: [
                    "2026-11-27": ([minutes(9, 30)..<minutes(13, 0)], [minutes(4, 0)..<minutes(9, 30)]),
                    "2026-12-24": ([minutes(9, 30)..<minutes(13, 0)], [minutes(4, 0)..<minutes(9, 30)])
                ]
            )
        case "ICE", "BOND":
            return makeSchedule(
                timeZoneID: "America/New_York",
                tradable: [minutes(20, 0)..<minutes(24, 0), minutes(0, 0)..<minutes(18, 0)],
                holidays: ["2026-01-01", "2026-01-19", "2026-02-16", "2026-04-03", "2026-05-25", "2026-06-19", "2026-07-03", "2026-09-07", "2026-11-26", "2026-12-25"]
            )
        case "CME", "CBOT", "NYMEX", "COMEX":
            return makeSchedule(
                timeZoneID: "America/Chicago",
                tradable: [minutes(17, 0)..<minutes(24, 0), minutes(0, 0)..<minutes(16, 0)],
                holidays: ["2026-01-01", "2026-01-19", "2026-02-16", "2026-04-03", "2026-05-25", "2026-06-19", "2026-07-03", "2026-09-07", "2026-11-26", "2026-12-25"],
                specialSessions: [
                    "2026-11-27": ([minutes(8, 30)..<minutes(12, 15)], []),
                    "2026-12-24": ([minutes(8, 30)..<minutes(12, 15)], [])
                ]
            )
        default:
            return nil
        }
    }
}
