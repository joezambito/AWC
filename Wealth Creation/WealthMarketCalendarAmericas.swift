import Foundation

extension WealthMarketCalendar {
    static func latinAmericaSchedule(for market: String, region: WealthMarketRegion) -> WealthMarketSchedule? {
        guard region == .latinAmerica else { return nil }

        switch market {
        case "BMV":
            return makeSchedule(
                timeZoneID: "America/Mexico_City",
                tradable: [minutes(8, 30)..<minutes(15, 0)],
                holidays: ["2026-01-01", "2026-02-02", "2026-03-16", "2026-04-02", "2026-04-03", "2026-05-01", "2026-09-16", "2026-11-02", "2026-11-16", "2026-12-25"]
            )
        case "B3":
            return makeSchedule(
                timeZoneID: "America/Sao_Paulo",
                tradable: [minutes(10, 0)..<minutes(17, 55)],
                holidays: ["2026-01-01", "2026-02-16", "2026-02-17", "2026-04-03", "2026-04-21", "2026-05-01", "2026-09-07", "2026-10-12", "2026-11-02", "2026-11-15", "2026-11-20", "2026-12-25"]
            )
        case "BCBA":
            return makeSchedule(
                timeZoneID: "America/Argentina/Buenos_Aires",
                tradable: [minutes(8, 30)..<minutes(15, 0)],
                holidays: ["2026-01-01", "2026-02-16", "2026-02-17", "2026-03-24", "2026-04-02", "2026-04-03", "2026-05-01", "2026-05-25", "2026-06-20", "2026-07-09", "2026-12-08", "2026-12-25"]
            )
        default:
            return nil
        }
    }
}
