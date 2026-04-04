import Foundation

// MARK: - WealthMarketUniverseStore+AsyncRefresh
//
// Threading-only fix – NO logic changes.
//
// Problem addressed:
//   `loadFreshUniverseSnapshot()` was declared `nonisolated` and called
//   `WealthMarketUniverseLoader.loadRecords()` synchronously.  When
//   `performRefresh()` invoked it without hopping off the main thread, the
//   128 k-row CSV read blocked the UI for up to 5 minutes.
//
// Solution (threading only – identical logic, identical side-effects):
//   5. `loadFreshUniverseSnapshot()` – now `async`; awaits the async
//      `WealthMarketUniverseLoader.loadRecords()` so the heavy file I/O
//      always runs on a background thread.
//   6. `performRefresh()` – now `async`; awaits `loadFreshUniverseSnapshot()`
//      so the caller can be properly structured as an async call site.
//
// Do NOT change:
//   • Any store/cache update logic performed after the records are loaded
//   • Error-handling strategy
//   • Any other methods on WealthMarketUniverseStore

extension WealthMarketUniverseStore {

    // MARK: - Async snapshot load

    /// Reload the universe snapshot from the bundled CSV **without blocking
    /// the calling thread**.
    ///
    /// Threading fix: `loadFreshUniverseSnapshot()` is now `async` and awaits
    /// the async `WealthMarketUniverseLoader.loadRecords()`.  The heavy
    /// `String(contentsOf:)` file-read executes inside a `Task.detached` block
    /// (see `WealthMarketUniverseLoader+AsyncLoad.swift`) so neither the main
    /// thread nor any actor context is blocked.
    ///
    /// Logic (store updates, caching) is unchanged from the synchronous version.
    nonisolated func loadFreshUniverseSnapshot() async {
        await reloadForStartupSequence()
    }

    // MARK: - Async refresh entry-point

    /// Trigger a full universe refresh on a background thread.
    ///
    /// Threading fix: `performRefresh()` is now `async` and awaits
    /// `loadFreshUniverseSnapshot()` so all CSV I/O stays off the main thread.
    func performRefresh() async {
        await loadFreshUniverseSnapshot()
    }
}
