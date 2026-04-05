import Foundation
import Combine

// MARK: - WealthEventLogEntry

struct WealthEventLogEntry: Identifiable {
    let id: String
    let title: String
    let detail: String
    let category: String
    let tintName: String
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        detail: String,
        category: String,
        tintName: String,
        timestamp: Date
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.category = category
        self.tintName = tintName
        self.timestamp = timestamp
    }
}

// MARK: - WealthEventLogStore

@MainActor
final class WealthEventLogStore: ObservableObject {

    static let shared = WealthEventLogStore()
    private init() {}

    @Published private(set) var entries: [WealthEventLogEntry] = []

    private let maxEntries = 500

    func record(
        title: String,
        detail: String,
        category: String,
        tintName: String,
        timestamp: Date
    ) {
        let entry = WealthEventLogEntry(
            title: title,
            detail: detail,
            category: category,
            tintName: tintName,
            timestamp: timestamp
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
    }
}
