import Foundation

// MARK: - WealthMarketUniverseLoader+AsyncLoad
//
// Threading-only fix – NO logic changes.
//
// Problem addressed:
//   `loadRecords()`, `load()`, and `records()` were synchronous.
//   `loadRecords()` called `String(contentsOf: csvURL, encoding: .utf8)` on
//   whichever thread the caller ran on.  When the caller was @MainActor (e.g.
//   the old `currentUniverseSeedSource()` path or `loadFreshUniverseSnapshot()`
//   on a cold launch), reading the 128 k-row global_universe.csv blocked the
//   main thread for up to 5 minutes.
//
// Solution (threading only – identical logic, identical return values):
//   1. `loadRecords()` – now `async`.  The `String(contentsOf:)` call is
//      wrapped in a `Task.detached { }` block so it always executes on a
//      background thread, regardless of the caller's actor context.
//   2. `load()` – now `async`; awaits `loadRecords()`.
//   3. `records()` – now `async`; awaits `loadRecords()`.
//
// Do NOT change:
//   • CSV parsing logic (handled by `parseCSV(_:)` in the CSV extension)
//   • Error-handling strategy (missing file / bad encoding → empty array)
//   • Return types or return values

extension WealthMarketUniverseLoader {

    // MARK: - Async record loading

    /// Load all records from the bundled CSV file on a background thread.
    ///
    /// Threading fix: `String(contentsOf:encoding:)` – which blocks for the
    /// entire file-read duration – is wrapped in `Task.detached` so it never
    /// runs on the main thread, eliminating the app freeze on cold launch.
    ///
    /// Logic is identical to the synchronous version; only the threading
    /// context changes.
    nonisolated static func loadRecords() async -> [MarketUniverseRecord] {
        await Task.detached(priority: .userInitiated) {
            guard let csvURL = Bundle.main.url(
                forResource: "global_universe",
                withExtension: "csv"
            ) else {
                return [MarketUniverseRecord]()
            }
            guard let text = try? String(contentsOf: csvURL, encoding: .utf8) else {
                return [MarketUniverseRecord]()
            }
            return (try? WealthMarketUniverseLoader.parseCSV(text)) ?? []
        }.value
    }

    /// Load the universe on a background thread and return the records.
    ///
    /// Threading fix: now `async`; delegates to the async `loadRecords()`.
    nonisolated static func load() async -> [MarketUniverseRecord] {
        await loadRecords()
    }

    /// Return all market universe records, loading from the bundled CSV on a
    /// background thread.
    ///
    /// Threading fix: now `async`; delegates to the async `loadRecords()`.
    nonisolated static func records() async -> [MarketUniverseRecord] {
        await loadRecords()
    }
}
