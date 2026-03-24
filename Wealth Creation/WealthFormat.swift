import Foundation

enum WealthFormat {
    static let appTimeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current

    static func money(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "A$%.2f", value)
    }

    static func compactMoney(_ value: Double) -> String {
        if abs(value) >= 1_000_000 { return String(format: "A$%.1fm", value / 1_000_000) }
        if abs(value) >= 1_000 { return String(format: "A$%.1fk", value / 1_000) }
        return money(value)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    static func clock(_ date: Date?) -> String {
        formatted(date, format: "HH:mm:ss", fallback: "--:--:--")
    }

    static func dayClock(_ date: Date?) -> String {
        formatted(date, format: "dd MMM h:mm a", fallback: "--")
    }

    static func age(_ date: Date?) -> String {
        guard let date else { return "Waiting" }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))

        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3_600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3_600)h" }
        return "\(seconds / 86_400)d"
    }

    static func ageText(_ date: Date?) -> String {
        let short = age(date)
        return short == "Waiting" ? short : "\(short) ago"
    }

    private static func formatted(_ date: Date?, format: String, fallback: String) -> String {
        guard let date else { return fallback }
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = appTimeZone
        return formatter.string(from: date)
    }
}
