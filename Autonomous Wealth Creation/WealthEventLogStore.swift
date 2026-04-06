import Foundation
import SwiftUI
import Combine

struct WealthEventLogEntry: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let detail: String
    let category: String
    let tintName: String
    let timestamp: Date

    var tint: Color {
        switch tintName {
        case "green": return WealthTheme.green
        case "orange": return WealthTheme.orange
        case "red": return WealthTheme.red
        case "purple": return WealthTheme.purple
        case "blue": return WealthTheme.blue
        default: return WealthTheme.cyan
        }
    }
}

@MainActor
final class WealthEventLogStore: ObservableObject {
    static let shared = WealthEventLogStore()

    @Published private(set) var entries: [WealthEventLogEntry]

    private let defaults = UserDefaults.standard
    private let storageKey = "awc_event_log_entries_v1"
    private let macLookbackDays = 30
    private let phoneLookbackDays = 7
    private let macEntryCap = 1_200
    private let phoneEntryCap = 240

    private init() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([WealthEventLogEntry].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }
        prune()
    }

    func record(title: String, detail: String, category: String, tintName: String, timestamp: Date = .now) {
        prune(now: timestamp)

        let entry = WealthEventLogEntry(
            id: UUID().uuidString,
            title: title,
            detail: detail,
            category: category,
            tintName: tintName,
            timestamp: timestamp
        )

        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(entryCap))
        persist()
    }

    func prune(now: Date = .now) {
        let cutoff = retentionCutoff(for: now)
        entries.removeAll { $0.timestamp < cutoff }
        persist()
    }

    var retentionLabel: String {
#if targetEnvironment(macCatalyst)
        return "PERMANENT MAC WINDOW"
#else
        return "LAST 7 DAYS"
#endif
    }

    var retentionSubtitle: String {
#if targetEnvironment(macCatalyst)
        return "Keeps the rolling last \(macLookbackDays) days for desktop review."
#else
        return "Keeps the rolling last \(phoneLookbackDays) days on phone."
#endif
    }

    private var entryCap: Int {
#if targetEnvironment(macCatalyst)
        return macEntryCap
#else
        return phoneEntryCap
#endif
    }

    private func retentionCutoff(for now: Date) -> Date {
#if targetEnvironment(macCatalyst)
        return Calendar.current.date(byAdding: .day, value: -macLookbackDays, to: now) ?? now
#else
        return Calendar.current.date(byAdding: .day, value: -phoneLookbackDays, to: now) ?? now
#endif
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
