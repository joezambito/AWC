import Foundation

extension WealthMarketCalendar {
    static func europeSchedule(for market: String, region: WealthMarketRegion) -> WealthMarketSchedule? {
        guard region == .europe else { return nil }

        switch market {
        case "LSE", "EU/UK":
            return makeSchedule(
                timeZoneID: "Europe/London",
                tradable: [minutes(8, 0)..<minutes(16, 30)],
                holidays: ["2026-01-01", "2026-04-03", "2026-04-06", "2026-05-04", "2026-05-25", "2026-08-31", "2026-12-25", "2026-12-28"]
            )
        case "XETRA":
            return makeSchedule(
                timeZoneID: "Europe/Berlin",
                tradable: [minutes(9, 0)..<minutes(17, 30)],
                holidays: ["2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-12-25"]
            )
        case "EURONEXT":
            return makeSchedule(
                timeZoneID: "Europe/Paris",
                tradable: [minutes(9, 0)..<minutes(17, 30)],
                holidays: ["2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-12-25"]
            )
        case "SIX":
            return makeSchedule(
                timeZoneID: "Europe/Zurich",
                tradable: [minutes(9, 0)..<minutes(17, 30)],
                holidays: ["2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-12-25"]
            )
        case "OMX":
            return makeSchedule(
                timeZoneID: "Europe/Stockholm",
                tradable: [minutes(9, 0)..<minutes(17, 30)],
                holidays: ["2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-12-25"]
            )
        case "WSE":
            return makeSchedule(
                timeZoneID: "Europe/Warsaw",
                tradable: [minutes(9, 0)..<minutes(17, 30)],
                holidays: ["2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-12-25"]
            )
        case "BME":
            return makeSchedule(
                timeZoneID: "Europe/Madrid",
                tradable: [minutes(9, 0)..<minutes(17, 30)],
                holidays: ["2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-12-25"]
            )
        case "BIT":
            return makeSchedule(
                timeZoneID: "Europe/Rome",
                tradable: [minutes(9, 0)..<minutes(17, 30)],
                holidays: ["2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-12-25"]
            )
        case "VSE":
            return makeSchedule(
                timeZoneID: "Europe/Vienna",
                tradable: [minutes(9, 0)..<minutes(17, 30)],
                holidays: ["2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-12-25"]
            )
        case "OSE":
            return makeSchedule(
                timeZoneID: "Europe/Oslo",
                tradable: [minutes(9, 0)..<minutes(17, 30)],
                holidays: ["2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-12-25"]
            )
        case "BIST":
            return makeSchedule(
                timeZoneID: "Europe/Istanbul",
                tradable: [minutes(9, 0)..<minutes(17, 30)]
            )
        case "MOEX":
            return makeSchedule(
                timeZoneID: "Europe/Moscow",
                tradable: [minutes(10, 0)..<minutes(18, 45)]
            )
        default:
            return nil
        }
    }
}
