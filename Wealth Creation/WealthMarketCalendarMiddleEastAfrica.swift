import Foundation

extension WealthMarketCalendar {
    static func middleEastAfricaSchedule(for market: String, region: WealthMarketRegion) -> WealthMarketSchedule? {
        guard region == .middleEastAfrica else { return nil }

        switch market {
        case "TADAWUL":
            return makeSchedule(
                timeZoneID: "Asia/Riyadh",
                weekdayTrading: 1...5,
                tradable: [minutes(10, 0)..<minutes(15, 0)],
                holidays: ["2026-03-20", "2026-03-21", "2026-03-22", "2026-06-17", "2026-06-18", "2026-09-23"]
            )
        case "QSE":
            return makeSchedule(
                timeZoneID: "Asia/Riyadh",
                tradable: [minutes(10, 0)..<minutes(13, 0)],
                holidays: ["2026-03-20", "2026-03-21", "2026-03-22", "2026-06-17", "2026-06-18", "2026-09-23"]
            )
        case "MSX":
            return makeSchedule(
                timeZoneID: "Asia/Dubai",
                tradable: [minutes(10, 0)..<minutes(13, 0)],
                holidays: ["2026-03-20", "2026-03-21", "2026-03-22", "2026-06-17", "2026-06-18", "2026-09-23"]
            )
        case "BHB":
            return makeSchedule(
                timeZoneID: "Asia/Dubai",
                tradable: [minutes(10, 0)..<minutes(13, 0)],
                holidays: ["2026-03-20", "2026-03-21", "2026-03-22", "2026-06-17", "2026-06-18", "2026-09-23"]
            )
        case "KSE":
            return makeSchedule(
                timeZoneID: "Asia/Kuwait",
                tradable: [minutes(9, 0)..<minutes(12, 30)],
                holidays: ["2026-03-20", "2026-03-21", "2026-03-22", "2026-06-17", "2026-06-18", "2026-09-23"]
            )
        case "DFM", "ADX":
            return makeSchedule(
                timeZoneID: "Asia/Dubai",
                tradable: [minutes(10, 0)..<minutes(14, 45)],
                holidays: ["2026-01-01", "2026-03-20", "2026-03-21", "2026-03-22", "2026-06-17", "2026-06-18", "2026-09-23", "2026-12-02", "2026-12-03"]
            )
        case "TASE":
            return makeSchedule(
                timeZoneID: "Asia/Jerusalem",
                tradable: [minutes(9, 45)..<minutes(17, 15)],
                holidays: ["2026-03-03", "2026-04-02", "2026-04-03", "2026-04-09", "2026-04-14", "2026-05-21", "2026-05-25", "2026-09-11", "2026-09-20", "2026-09-21", "2026-09-22", "2026-09-30", "2026-10-01", "2026-10-02"]
            )
        case "JSE":
            return makeSchedule(
                timeZoneID: "Africa/Johannesburg",
                tradable: [minutes(9, 0)..<minutes(17, 0)],
                holidays: ["2026-01-01", "2026-03-21", "2026-04-03", "2026-04-06", "2026-04-27", "2026-05-01", "2026-06-16", "2026-08-10", "2026-09-24", "2026-12-16", "2026-12-25"]
            )
        case "EGX":
            return makeSchedule(
                timeZoneID: "Africa/Cairo",
                tradable: [minutes(10, 0)..<minutes(14, 30)],
                holidays: ["2026-01-07", "2026-01-25", "2026-03-20", "2026-03-21", "2026-04-20", "2026-04-21", "2026-04-25", "2026-05-01", "2026-06-30", "2026-07-23", "2026-09-23", "2026-10-06"]
            )
        default:
            return nil
        }
    }
}
