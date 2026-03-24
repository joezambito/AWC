import Foundation

struct WealthMarketSchedule {
    let timeZone: TimeZone
    let weekdayTrading: ClosedRange<Int>
    let tradable: [Range<Int>]
    let afterHours: [Range<Int>]
    let holidays: Set<String>
    let specialSessions: [String: WealthMarketCalendar.SessionWindows]
}

enum WealthMarketCalendar {
    typealias SessionWindows = (tradable: [Range<Int>], afterHours: [Range<Int>])
    typealias SpecialSessions = [String: SessionWindows]
}

extension WealthMarketCalendar {
    static func localMinuteOfDay(in timeZone: TimeZone, date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return (calendar.component(.hour, from: date) * 60) + calendar.component(.minute, from: date)
    }

    static func localWeekday(in timeZone: TimeZone, date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(.weekday, from: date)
    }

    static func localDayKey(in timeZone: TimeZone, date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func fxState(date: Date) -> MarketSessionState {
        let london = TimeZone(identifier: "Europe/London") ?? .current
        let weekday = localWeekday(in: london, date: date)
        let minuteOfDay = localMinuteOfDay(in: london, date: date)

        if weekday == 1 && minuteOfDay >= minutes(22, 0) { return .tradableNow }
        if (2...6).contains(weekday) { return .tradableNow }
        if weekday == 7 && minuteOfDay < minutes(22, 0) { return .recheckAtOpen }
        return .waitingForOpen
    }

    static func nextWindowStart(
        in timeZone: TimeZone,
        windowsForDay: (_ weekday: Int, _ dayKey: String) -> (starts: [Int], restrictWeekday: Bool),
        date: Date
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        for dayOffset in 0...10 {
            guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }

            let weekday = calendar.component(.weekday, from: candidateDay)
            let dayKey = localDayKey(in: timeZone, date: candidateDay)
            let config = windowsForDay(weekday, dayKey)
            let currentMinute = dayOffset == 0 ? localMinuteOfDay(in: timeZone, date: date) : -1

            for startMinute in config.starts.sorted() where dayOffset > 0 || startMinute > currentMinute {
                var components = calendar.dateComponents([.year, .month, .day], from: candidateDay)
                components.hour = startMinute / 60
                components.minute = startMinute % 60
                if let openDate = calendar.date(from: components) {
                    return openDate
                }
            }
        }

        return nil
    }

    static func makeSchedule(
        timeZoneID: String,
        weekdayTrading: ClosedRange<Int> = 2...6,
        tradable: [Range<Int>],
        afterHours: [Range<Int>] = [],
        holidays: Set<String> = [],
        specialSessions: SpecialSessions = [:]
    ) -> WealthMarketSchedule {
        WealthMarketSchedule(
            timeZone: TimeZone(identifier: timeZoneID) ?? .current,
            weekdayTrading: weekdayTrading,
            tradable: tradable,
            afterHours: afterHours,
            holidays: holidays,
            specialSessions: specialSessions
        )
    }

    static func fallbackSchedule() -> WealthMarketSchedule {
        makeSchedule(
            timeZoneID: TimeZone.current.identifier,
            tradable: [minutes(9, 0)..<minutes(16, 0)]
        )
    }

    static func minutes(_ hour: Int, _ minute: Int) -> Int {
        (hour * 60) + minute
    }

    static func tradingWindows(for schedule: WealthMarketSchedule, dayKey: String) -> SessionWindows {
        schedule.specialSessions[dayKey] ?? (schedule.tradable, schedule.afterHours)
    }
}
