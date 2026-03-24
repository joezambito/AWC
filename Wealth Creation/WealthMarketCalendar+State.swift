import Foundation

extension WealthMarketCalendar {
    static func state(for market: String, date: Date = .now) -> MarketSessionState {
        let canonicalMarket = canonicalMarket(for: market)

        if canonicalMarket.contains("CRYPTO") {
            return .tradableNow
        }

        if canonicalMarket == "FX" {
            return fxState(date: date)
        }

        let schedule = schedule(for: canonicalMarket)
        let dayKey = localDayKey(in: schedule.timeZone, date: date)
        let weekday = localWeekday(in: schedule.timeZone, date: date)

        guard !schedule.holidays.contains(dayKey) else {
            return .recheckAtOpen
        }

        guard schedule.weekdayTrading.contains(weekday) else {
            return .recheckAtOpen
        }

        let windows = tradingWindows(for: schedule, dayKey: dayKey)
        let minuteOfDay = localMinuteOfDay(in: schedule.timeZone, date: date)

        if windows.tradable.contains(where: { $0.contains(minuteOfDay) }) {
            return .tradableNow
        }

        if windows.afterHours.contains(where: { $0.contains(minuteOfDay) }) {
            return .afterHours
        }

        return .waitingForOpen
    }

    static func nextTradingDate(for market: String, date: Date = .now) -> Date? {
        nextTradingDate(for: market, date: date, includeAfterHours: false)
    }

    static func nextTradingDate(
        for market: String,
        date: Date = .now,
        includeAfterHours: Bool
    ) -> Date? {
        let canonicalMarket = canonicalMarket(for: market)

        if canonicalMarket.contains("CRYPTO") {
            return date
        }

        if canonicalMarket == "FX" {
            let london = TimeZone(identifier: "Europe/London") ?? .current
            return nextWindowStart(
                in: london,
                windowsForDay: { weekday, _ in
                    switch weekday {
                    case 1, 7: return ([minutes(22, 0)], false)
                    case 2...6: return ([0], false)
                    default: return ([], false)
                    }
                },
                date: date
            )
        }

        let schedule = schedule(for: canonicalMarket)
        return nextWindowStart(
            in: schedule.timeZone,
            windowsForDay: { weekday, dayKey in
                guard schedule.weekdayTrading.contains(weekday), !schedule.holidays.contains(dayKey) else {
                    return ([], true)
                }

                let windows = tradingWindows(for: schedule, dayKey: dayKey)
                let tradableStarts = windows.tradable.map(\.lowerBound)
                let afterHoursStarts = windows.afterHours.map(\.lowerBound)
                return (includeAfterHours ? (tradableStarts + afterHoursStarts) : tradableStarts, true)
            },
            date: date
        )
    }
}
