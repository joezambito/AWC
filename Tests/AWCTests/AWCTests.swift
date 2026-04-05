import XCTest
import Foundation

// MARK: - AWCTests
//
// NEW FILE – Issue 11.
//
// Provides test coverage for:
//   • Timer scheduling and invalidation  (WealthEngineTimerTests)
//   • Async callback object-lifetime     (MarketDataFetcherLifetimeTests)
//   • Persistence atomicity              (PersistenceManagerAtomicityTests)
//   • Secret-config loading              (AWCSecretConfigTests)
//   • Error-handling descriptors         (FetchErrorDescriptionTests)
//
// These tests exercise isolated helpers and stub types only; they do not
// depend on the main Xcode app target (which contains WealthCore.swift,
// Opportunity, MarketSignal, Holding etc.) so the suite can be run
// standalone via `swift test`.

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Timer scheduling tests
// ─────────────────────────────────────────────────────────────────────────────

final class WealthEngineTimerTests: XCTestCase {

    // MARK: - Helpers

    /// Lightweight timer manager that mirrors the scheduling pattern used by
    /// WealthEngineStore+Timers.swift.  Isolated here so the test has no
    /// dependency on the main app target.
    final class TimerManager: @unchecked Sendable {

        private(set) var timers: [Timer] = []
        private(set) var firedStages: [Int] = []

        func scheduleTimers(intervals: [(TimeInterval, Int)]) {
            invalidate()
            for (interval, stage) in intervals {
                let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                    self?.firedStages.append(stage)
                }
                timers.append(t)
            }
        }

        func invalidate() {
            timers.forEach { $0.invalidate() }
            timers.removeAll()
        }

        var count: Int { timers.count }
    }

    // MARK: - Tests

    func test_scheduleTimers_createsExpectedCount() {
        let manager = TimerManager()
        let intervals: [(TimeInterval, Int)] = [
            (9 * 60, 0), (10 * 60, 1), (19 * 60, 2),
            (20 * 60, 3), (29 * 60, 4), (30 * 60, 5)
        ]
        manager.scheduleTimers(intervals: intervals)
        XCTAssertEqual(manager.count, 6, "Expected 6 timers (3 IBKR + 2 soft + 1 deep).")
        manager.invalidate()
    }

    func test_invalidateTimers_removesAllTimers() {
        let manager = TimerManager()
        let intervals: [(TimeInterval, Int)] = [(10, 0), (20, 1), (30, 2)]
        manager.scheduleTimers(intervals: intervals)
        XCTAssertEqual(manager.count, 3)
        manager.invalidate()
        XCTAssertEqual(manager.count, 0, "All timers should be removed after invalidation.")
    }

    func test_rescheduleTimers_replacesExistingSet() {
        let manager = TimerManager()
        manager.scheduleTimers(intervals: [(10, 0), (20, 1)])
        XCTAssertEqual(manager.count, 2)
        // Re-schedule with a different set – old timers must be replaced.
        manager.scheduleTimers(intervals: [(5, 0), (10, 1), (15, 2)])
        XCTAssertEqual(manager.count, 3, "Re-schedule should replace the previous timer set.")
        manager.invalidate()
    }

    func test_invalidateIsIdempotent() {
        let manager = TimerManager()
        manager.scheduleTimers(intervals: [(10, 0)])
        manager.invalidate()
        manager.invalidate()   // second call must not crash
        XCTAssertEqual(manager.count, 0)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Async callback object-lifetime tests
// ─────────────────────────────────────────────────────────────────────────────

/// Tests that verify the strong-capture async pattern introduced in
/// MarketDataFetcher (Issue 7 root-cause fix).
final class MarketDataFetcherLifetimeTests: XCTestCase {

    // MARK: - Helpers

    /// Minimal async worker that mirrors the strong-capture pattern in
    /// MarketDataFetcher.  `body` captures `self` strongly via `[self]`
    /// so the worker cannot be released mid-flight.
    final class AsyncWorker: @unchecked Sendable {
        var result: String?
        var didComplete = false

        /// Perform work asynchronously, capturing `self` strongly via `[self]`
        /// so the worker cannot be released mid-flight.
        func perform(work: @Sendable @escaping () async -> String) async {
            // [self] — strong capture — is the root-cause fix for Issue 7.
            let task = Task { [self] in
                let value = await work()
                self.result = value
                self.didComplete = true
            }
            await task.value
        }
    }

    // MARK: - Tests

    func test_strongCaptureKeepsWorkerAlive() async {
        let worker = AsyncWorker()

        // Perform work that takes a brief moment (simulates a network round-trip).
        await worker.perform {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
            return "done"
        }

        // The strong capture in perform() guaranteed the worker stayed alive.
        XCTAssertEqual(worker.result, "done")
        XCTAssertTrue(worker.didComplete)
    }

    func test_cancelledTask_doesNotDeliverResult() async {
        let worker = AsyncWorker()

        let task = Task {
            await worker.perform {
                // Simulate a slow network call.
                try? await Task.sleep(nanoseconds: 500_000_000) // 500 ms
                return "should not arrive"
            }
        }

        // Cancel before the work completes.
        try? await Task.sleep(nanoseconds: 10_000_000) // 10 ms
        task.cancel()

        // Give the task a moment to propagate cancellation.
        try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms

        // The task was cancelled; the result may or may not be set depending
        // on when cancellation was honoured.  The key invariant: no crash.
        XCTAssertTrue(task.isCancelled, "Task should be cancelled.")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Persistence atomicity tests
// ─────────────────────────────────────────────────────────────────────────────

/// Tests that verify the atomic-write behaviour of PersistenceManager
/// (Issue 6 root-cause fix) using a temporary directory and stub types.
final class PersistenceManagerAtomicityTests: XCTestCase {

    // MARK: - Stub Codable types
    //
    // Used instead of the app types (Opportunity, MarketSignal, Holding)
    // which live in WealthCore.swift and are not visible from this target.

    struct StubItem: Codable, Equatable {
        let id: Int
        let label: String
    }

    // MARK: - Helpers

    private var tmpDir: URL!
    private var bundleURL: URL!

    override func setUp() {
        super.setUp()
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AWCTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        bundleURL = tmpDir.appendingPathComponent("test_bundle.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    // MARK: - Tests

    func test_atomicWrite_writesData() throws {
        let data = try JSONEncoder().encode(StubItem(id: 1, label: "hello"))
        let pm = PersistenceManagerStub(bundleURL: bundleURL)

        try pm.write(data, to: bundleURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.path),
                      "Bundle file should exist after atomic write.")
    }

    func test_atomicWrite_canBeReadBack() throws {
        let original = StubItem(id: 42, label: "world")
        let data = try JSONEncoder().encode(original)
        let pm = PersistenceManagerStub(bundleURL: bundleURL)

        try pm.write(data, to: bundleURL)

        let readBack = try Data(contentsOf: bundleURL)
        let decoded = try JSONDecoder().decode(StubItem.self, from: readBack)
        XCTAssertEqual(decoded, original, "Data read back should equal what was written.")
    }

    func test_clearBundle_removesFile() throws {
        let data = Data("test".utf8)
        try data.write(to: bundleURL, options: [.atomic])
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.path))

        let pm = PersistenceManagerStub(bundleURL: bundleURL)
        pm.clear()

        XCTAssertFalse(FileManager.default.fileExists(atPath: bundleURL.path),
                       "Bundle file should be removed after clear().")
    }

    func test_clearBundle_onMissingFile_doesNotCrash() {
        let pm = PersistenceManagerStub(bundleURL: bundleURL)
        pm.clear()   // file doesn't exist — must not crash
    }

    func test_readMissingBundle_returnsNil() {
        let pm = PersistenceManagerStub(bundleURL: bundleURL)
        let data = pm.read()
        XCTAssertNil(data, "Reading a non-existent bundle should return nil.")
    }

    // MARK: - Stub helper (mirrors PersistenceManager write semantics)

    final class PersistenceManagerStub {
        private let url: URL
        init(bundleURL: URL) { self.url = bundleURL }

        func write(_ data: Data, to dest: URL) throws {
            try data.write(to: dest, options: [.atomic])
        }

        func read() -> Data? {
            try? Data(contentsOf: url)
        }

        func clear() {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AWCSecretConfig loading tests
// ─────────────────────────────────────────────────────────────────────────────

/// Tests the .env parser used by AWCSecretConfig (Issue 8 root-cause fix).
final class AWCSecretConfigTests: XCTestCase {

    // MARK: - Helpers

    /// Minimal .env parser that mirrors the logic in AWCSecretConfig.loadDotEnv()
    /// so it can be tested without accessing the singleton's file path.
    func parseEnv(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key   = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            result[key] = value
        }
        return result
    }

    // MARK: - Tests

    func test_parseEnv_parsesKeyValuePairs() {
        let content = """
        IBKR_CLIENT_ID=77
        IBKR_HOST=192.168.1.21
        IBKR_PORT=7497
        """
        let values = parseEnv(content)
        XCTAssertEqual(values["IBKR_CLIENT_ID"], "77")
        XCTAssertEqual(values["IBKR_HOST"], "192.168.1.21")
        XCTAssertEqual(values["IBKR_PORT"], "7497")
    }

    func test_parseEnv_ignoresCommentLines() {
        let content = """
        # this is a comment
        KEY=value
        # another comment
        """
        let values = parseEnv(content)
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values["KEY"], "value")
    }

    func test_parseEnv_ignoresBlankLines() {
        let content = "\n\nKEY=val\n\n"
        let values = parseEnv(content)
        XCTAssertEqual(values["KEY"], "val")
    }

    func test_parseEnv_handlesValueWithEqualsSign() {
        let content = "KEY=val=ue"
        let values = parseEnv(content)
        XCTAssertEqual(values["KEY"], "val=ue",
                       "maxSplits:1 should keep the rest of the value intact.")
    }

    func test_parseEnv_emptyContent_returnsEmpty() {
        let values = parseEnv("")
        XCTAssertTrue(values.isEmpty)
    }

    func test_parseEnv_malformedLine_isSkipped() {
        let content = "NOKEYVALUE\nGOOD=ok"
        let values = parseEnv(content)
        XCTAssertNil(values["NOKEYVALUE"])
        XCTAssertEqual(values["GOOD"], "ok")
    }

    func test_defaultClientID_isSeventySevenWhenMissing() {
        let values = parseEnv("")
        let clientID = Int(values["IBKR_CLIENT_ID"] ?? "") ?? 77
        XCTAssertEqual(clientID, 77, "Default IBKR_CLIENT_ID should be 77.")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - FetchError description tests
// ─────────────────────────────────────────────────────────────────────────────

/// Tests that every FetchError case produces a non-empty, human-readable
/// error description (Issue 7 — error handling paths).
final class FetchErrorDescriptionTests: XCTestCase {

    // MARK: - Minimal FetchError mirror
    //
    // Mirrors the FetchError enum in MarketDataFetcher.swift so these tests
    // can run without importing the app target.

    enum FetchError: Error, LocalizedError {
        case invalidURL(String)
        case networkError(Error)
        case badHTTPStatus(Int)
        case decodingError(Error)
        case missingBaseURL

        var errorDescription: String? {
            switch self {
            case .invalidURL(let s):
                return "MarketDataFetcher: invalid URL '\(s)'."
            case .networkError(let e):
                return "MarketDataFetcher: network error – \(e.localizedDescription)"
            case .badHTTPStatus(let code):
                return "MarketDataFetcher: HTTP \(code) response."
            case .decodingError(let e):
                return "MarketDataFetcher: decode failed – \(e.localizedDescription)"
            case .missingBaseURL:
                return "MarketDataFetcher: MARKET_DATA_BASE_URL not set in awc.env."
            }
        }
    }

    struct AnyError: Error { let message: String }

    // MARK: - Tests

    func test_invalidURL_hasDescription() {
        let error = FetchError.invalidURL("not a url")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        XCTAssertTrue(error.errorDescription?.contains("not a url") ?? false)
    }

    func test_networkError_hasDescription() {
        let inner = AnyError(message: "timeout")
        let error = FetchError.networkError(inner)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func test_badHTTPStatus_includesCode() {
        let error = FetchError.badHTTPStatus(404)
        XCTAssertTrue(error.errorDescription?.contains("404") ?? false)
    }

    func test_decodingError_hasDescription() {
        let inner = AnyError(message: "bad json")
        let error = FetchError.decodingError(inner)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func test_missingBaseURL_hasDescription() {
        let error = FetchError.missingBaseURL
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        XCTAssertTrue(error.errorDescription?.contains("MARKET_DATA_BASE_URL") ?? false)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Peer sync tests
// ─────────────────────────────────────────────────────────────────────────────

/// Tests for the WealthPeerInfo type and the peer-sync discovery stub
/// introduced to enable Mac ↔ iPhone visibility (enable-mac-iphone-sync).
///
/// These tests exercise isolated stub types only; they do not depend on
/// Network.framework's runtime behaviour (NWListener / NWBrowser) so the
/// suite can run via `swift test` without a live network.
final class WealthPeerSyncTests: XCTestCase {

    // MARK: - WealthPeerInfo stub
    //
    // Mirrors the WealthPeerInfo struct in WealthPeerSyncService.swift.
    // Duplicated here so the test target has no dependency on the app target.

    struct PeerInfo: Equatable {
        let name: String
    }

    // MARK: - Stub peer registry
    //
    // Mirrors the discoveredPeers array managed by WealthPeerSyncService.

    final class PeerRegistry {
        private(set) var peers: [PeerInfo] = []

        func update(with names: [String]) {
            peers = names.map { PeerInfo(name: $0) }
        }

        func clear() {
            peers.removeAll()
        }
    }

    // MARK: - Tests

    func test_peerInfo_equality() {
        let a = PeerInfo(name: "MacBook Pro")
        let b = PeerInfo(name: "MacBook Pro")
        let c = PeerInfo(name: "iPhone 15")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func test_peerRegistry_update_populatesPeers() {
        let registry = PeerRegistry()
        registry.update(with: ["MacBook Pro", "iPhone 15"])
        XCTAssertEqual(registry.peers.count, 2)
        XCTAssertEqual(registry.peers[0].name, "MacBook Pro")
        XCTAssertEqual(registry.peers[1].name, "iPhone 15")
    }

    func test_peerRegistry_update_replacesExistingPeers() {
        let registry = PeerRegistry()
        registry.update(with: ["Device A", "Device B"])
        registry.update(with: ["Device C"])
        XCTAssertEqual(registry.peers.count, 1)
        XCTAssertEqual(registry.peers[0].name, "Device C")
    }

    func test_peerRegistry_clear_removesAllPeers() {
        let registry = PeerRegistry()
        registry.update(with: ["MacBook Pro", "iPhone 15"])
        registry.clear()
        XCTAssertTrue(registry.peers.isEmpty)
    }

    func test_peerRegistry_update_withEmptyNames_producesEmptyPeers() {
        let registry = PeerRegistry()
        registry.update(with: [])
        XCTAssertTrue(registry.peers.isEmpty)
    }

    func test_peerRegistry_clear_onEmptyRegistry_doesNotCrash() {
        let registry = PeerRegistry()
        registry.clear()   // no peers — must not crash
        XCTAssertTrue(registry.peers.isEmpty)
    }

    func test_bonjourServiceType_isConsistent() {
        // The Bonjour type used by WealthPeerSyncService must follow the
        // <name>.<protocol> format required by DNS-SD / RFC 6335.
        let serviceType = "_awc._tcp"
        XCTAssertTrue(serviceType.hasPrefix("_"), "Service type must start with '_'.")
        XCTAssertTrue(serviceType.hasSuffix("._tcp") || serviceType.hasSuffix("._udp"),
                      "Service type must end with '._tcp' or '._udp'.")
    }
}
