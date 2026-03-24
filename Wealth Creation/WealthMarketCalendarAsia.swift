import Foundation

extension WealthMarketCalendar {
    static func asiaSchedule(for market: String, region: WealthMarketRegion) -> WealthMarketSchedule? {
        guard region == .asia else { return nil }

        switch market {
        case "NSE":
            return makeSchedule(
                timeZoneID: "Asia/Kolkata",
                tradable: [minutes(9, 15)..<minutes(15, 30)]
            )
        case "KRX":
            return makeSchedule(
                timeZoneID: "Asia/Seoul",
                tradable: [minutes(9, 0)..<minutes(15, 30)],
                holidays: ["2026-01-01", "2026-02-16", "2026-02-17", "2026-02-18", "2026-03-01", "2026-05-05", "2026-05-25", "2026-06-06", "2026-08-15", "2026-09-24", "2026-09-25", "2026-09-26", "2026-10-03", "2026-10-09", "2026-12-25"]
            )
        case "TWSE", "TPEX":
            return makeSchedule(
                timeZoneID: "Asia/Taipei",
                tradable: [minutes(9, 0)..<minutes(13, 30)],
                holidays: ["2026-01-01", "2026-02-16", "2026-02-17", "2026-02-18", "2026-02-19", "2026-02-20", "2026-02-27", "2026-04-03", "2026-04-06", "2026-05-01", "2026-06-19", "2026-09-25", "2026-10-09", "2026-10-10"]
            )
        case "SGX":
            return makeSchedule(
                timeZoneID: "Asia/Singapore",
                tradable: [minutes(9, 0)..<minutes(17, 0)],
                holidays: ["2026-01-01", "2026-02-17", "2026-02-18", "2026-04-03", "2026-05-01", "2026-05-25", "2026-05-31", "2026-08-09", "2026-11-15", "2026-12-25"]
            )
        case "IDX":
            return makeSchedule(
                timeZoneID: "Asia/Jakarta",
                tradable: [minutes(9, 0)..<minutes(12, 0), minutes(13, 30)..<minutes(16, 0)],
                holidays: ["2026-01-01", "2026-02-17", "2026-03-19", "2026-03-20", "2026-03-23", "2026-04-03", "2026-05-01", "2026-05-14", "2026-05-26", "2026-06-17", "2026-08-17", "2026-12-25"]
            )
        case "BURSA":
            return makeSchedule(
                timeZoneID: "Asia/Kuala_Lumpur",
                tradable: [minutes(9, 0)..<minutes(12, 30), minutes(14, 30)..<minutes(17, 0)],
                holidays: ["2026-01-01", "2026-02-17", "2026-02-18", "2026-05-01", "2026-05-17", "2026-05-26", "2026-06-02", "2026-08-31", "2026-09-16", "2026-12-25"]
            )
        case "SET":
            return makeSchedule(
                timeZoneID: "Asia/Bangkok",
                tradable: [minutes(10, 0)..<minutes(12, 30), minutes(14, 30)..<minutes(16, 30)],
                holidays: ["2026-01-01", "2026-03-02", "2026-04-06", "2026-04-13", "2026-04-14", "2026-04-15", "2026-05-01", "2026-05-04", "2026-06-03", "2026-07-30", "2026-08-12", "2026-10-13", "2026-12-10", "2026-12-31"]
            )
        case "PSE":
            return makeSchedule(
                timeZoneID: "Asia/Manila",
                tradable: [minutes(9, 30)..<minutes(15, 0)],
                holidays: ["2026-01-01", "2026-04-02", "2026-04-03", "2026-04-09", "2026-05-01", "2026-06-12", "2026-08-31", "2026-11-30", "2026-12-25", "2026-12-30"]
            )
        case "HOSE", "HNX":
            return makeSchedule(
                timeZoneID: "Asia/Ho_Chi_Minh",
                tradable: [minutes(9, 0)..<minutes(11, 30), minutes(13, 0)..<minutes(14, 30)],
                holidays: ["2026-01-01", "2026-02-16", "2026-02-17", "2026-02-18", "2026-02-19", "2026-02-20", "2026-04-30", "2026-05-01", "2026-09-02"]
            )
        default:
            return nil
        }
    }
}
