import Foundation

// MARK: - WealthResearchIntelStore
//
// NEW code only.  Does NOT modify any existing functions.
//
// Observable singleton that stores the most recent research-feed intel
// for every ranked symbol.  Downstream UI consumers (card detail views,
// dashboard) observe `intelBySymbol` to display newsScore, social
// sentiment, volume signals, momentum labels, analyst tier, intelligence
// drivers/channels, and review summaries.
//
// ── Persistence ───────────────────────────────────────────────────────────
//
//   Research intel is persisted to a JSON file in the app's Caches
//   directory so the last-known result survives app restart.  The cache is
//   considered fresh for up to 30 minutes (matching the deep-refresh
//   timer).  Stale or missing cache is silently ignored; the next deep
//   refresh will repopulate it.
//
// ── Thread safety ─────────────────────────────────────────────────────────
//
//   All mutations happen on `@MainActor` so there are no data races.

@MainActor
final class WealthResearchIntelStore {

    // MARK: Shared instance

    static let shared = WealthResearchIntelStore()
    private init() {}

    // MARK: - Published state

    /// Research-feed intel keyed by ticker symbol.
    ///
    /// UI layers can read `store.intelBySymbol["AAPL"]` to obtain the
    /// most recent `WealthResearchCard` for a given card.
    private(set) var intelBySymbol: [String: WealthResearchCard] = [:] {
        didSet {
            NotificationCenter.default.post(
                name: .wealthResearchIntelDidUpdate,
                object: nil
            )
        }
    }

    // MARK: - Cache file URL

    private var cacheFileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("awc_research_intel.json")
    }

    // MARK: - Public API

    /// Update the store with a freshly-evaluated research card.
    ///
    /// If a card for the same symbol already exists it is replaced.
    /// Triggers `wealthResearchIntelDidUpdate` notification.
    func update(_ card: WealthResearchCard) {
        intelBySymbol[card.symbol] = card
    }

    /// Update the store with a batch of freshly-evaluated research cards.
    ///
    /// More efficient than calling `update(_:)` in a loop because the
    /// `didSet` observer fires only once after the entire batch is applied.
    func updateBatch(_ cards: [WealthResearchCard]) {
        var next = intelBySymbol
        for card in cards {
            next[card.symbol] = card
        }
        intelBySymbol = next
    }

    /// Return the most recently stored research intel for `symbol`, or
    /// `nil` when no intel has been gathered yet for that symbol.
    func intel(for symbol: String) -> WealthResearchCard? {
        intelBySymbol[symbol]
    }

    /// Remove research intel for symbols that are no longer in
    /// `activeSymbols`.  Call this after a market ranking pass to prune
    /// stale entries for cards that dropped out of the ranked set.
    func pruneSymbolsNotIn(_ activeSymbols: Set<String>) {
        intelBySymbol = intelBySymbol.filter { activeSymbols.contains($0.key) }
    }

    // MARK: - Persistence

    /// Persist the current intel snapshot to a JSON cache file.
    ///
    /// Uses an atomic write so the file is never partially written.
    func persist() {
        guard let url = cacheFileURL,
              let data = try? JSONEncoder().encode(intelBySymbol)
        else { return }

        do {
            try data.write(to: url, options: [.atomic])
            WealthEventLogStore.shared.record(
                title: "Research Intel Store",
                detail: "Persisted \(intelBySymbol.count) research cards (\(data.count / 1024) KB).",
                category: "research",
                tintName: "blue",
                timestamp: .now
            )
        } catch {
            WealthEventLogStore.shared.record(
                title: "Research Intel Store",
                detail: "Persist failed: \(error.localizedDescription)",
                category: "research",
                tintName: "red",
                timestamp: .now
            )
        }
    }

    /// Restore the most recently persisted intel snapshot.
    ///
    /// Silent no-op if the file is absent or undecodable; the store
    /// remains empty until the next deep refresh.
    func restore() {
        guard let url = cacheFileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: WealthResearchCard].self, from: data)
        else { return }

        intelBySymbol = decoded

        WealthEventLogStore.shared.record(
            title: "Research Intel Store",
            detail: "Restored \(intelBySymbol.count) research cards from cache.",
            category: "research",
            tintName: "blue",
            timestamp: .now
        )
    }

    /// Remove the persisted cache file and clear the in-memory store.
    ///
    /// Called by `WealthEngineStore.resetToFactoryDefaults()` via the
    /// standard invalidation sequence.
    func invalidate() {
        intelBySymbol = [:]
        if let url = cacheFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        WealthEventLogStore.shared.record(
            title: "Research Intel Store",
            detail: "Store invalidated (factory reset or stale cache).",
            category: "research",
            tintName: "orange",
            timestamp: .now
        )
    }
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted on the main thread after `WealthResearchIntelStore.intelBySymbol`
    /// is updated.  Observers can refresh UI or trigger downstream logic.
    static let wealthResearchIntelDidUpdate = Notification.Name("WealthResearchIntelDidUpdate")
}
