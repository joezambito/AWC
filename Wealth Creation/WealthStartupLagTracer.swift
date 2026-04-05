import Foundation

// MARK: - WealthStartupLagTracer
//
// NEW FILE — Startup Audit & Lag Tracing
//
// Purpose:
//   Observe and record which subsystems fire during app launch and the elapsed
//   time at each phase.  This file is purely additive — it does not change any
//   existing logic, function, or behaviour.
//
// How it works:
//   • `WealthStartupLagTracer.shared.trace(_:)` is called at key startup call
//     sites (WealthAppSessionController, WealthEngineStartupController).
//   • Each call records a `TraceEvent` (label + elapsed time since the first
//     trace call) and immediately prints to the Xcode debug console so startup
//     lag is visible without any additional tooling.
//   • All events are also forwarded to `WealthEventLogStore` so they appear in
//     the in-app event log alongside other engine events.
//   • `printSummary()` emits the complete ordered trace to the console; it is
//     called automatically when the startup sequence completes.
//
// Thread safety:
//   The class is `@MainActor`-isolated.  Every call site in the startup flow
//   already runs on the main actor, so no extra synchronisation is required.

// MARK: - TraceEvent

/// A single recorded trace point captured during the startup sequence.
struct WealthStartupTraceEvent {
    /// Human-readable description of what fired at this point.
    let label: String
    /// Seconds elapsed since `WealthStartupLagTracer.shared` was first accessed.
    let elapsedSinceLaunch: TimeInterval
    /// Wall-clock timestamp of the event.
    let date: Date
}

// MARK: - WealthStartupLagTracer

/// Minimal startup timing tracer.
///
/// Records a timestamped entry every time `trace(_:)` is called and
/// immediately prints the elapsed time to the Xcode console so startup lag is
/// visible during development and testing without any instrumentation tool.
///
/// Does not alter any existing logic.
@MainActor
final class WealthStartupLagTracer {

    // MARK: Shared instance

    static let shared = WealthStartupLagTracer()

    // MARK: Private state

    /// Wall-clock moment when the tracer singleton was first accessed.
    /// All elapsed times are measured relative to this baseline.
    private let launchDate: Date

    // MARK: Public state

    /// Ordered list of all recorded trace events for the current launch session.
    private(set) var events: [WealthStartupTraceEvent] = []

    // MARK: Init

    private init() {
        launchDate = .now
    }

    // MARK: - Public API

    /// Record a single trace point.
    ///
    /// - Parameter label: Short description of the subsystem or function that
    ///   just fired (e.g. `"prepareLaunch – start"`, `"universeScan – done"`).
    ///
    /// Immediately prints to the Xcode debug console:
    /// ```
    /// [AWC·Startup] +  0.002s  prepareLaunch – start
    /// ```
    /// Also forwards the event to `WealthEventLogStore` so it appears in the
    /// in-app event log.
    func trace(_ label: String) {
        let now = Date.now
        let elapsed = now.timeIntervalSince(launchDate)
        let event = WealthStartupTraceEvent(
            label: label,
            elapsedSinceLaunch: elapsed,
            date: now
        )
        events.append(event)

        // ── Console output (visible in Xcode debug console) ───────────
        print(String(format: "[AWC·Startup] +%7.3fs  %@", elapsed, label))

        // ── In-app event log ──────────────────────────────────────────
        WealthEventLogStore.shared.record(
            title: "Startup Tracer",
            detail: String(format: "+%.3fs  %@", elapsed, label),
            category: "startup",
            tintName: "cyan",
            timestamp: now
        )
    }

    // MARK: - Summary

    /// Human-readable summary of all recorded trace events.
    var summary: String {
        guard !events.isEmpty else { return "[AWC·Startup] No events recorded." }
        return events
            .map { String(format: "[AWC·Startup] +%7.3fs  %@", $0.elapsedSinceLaunch, $0.label) }
            .joined(separator: "\n")
    }

    /// Print the full startup trace summary to the Xcode debug console.
    ///
    /// Called automatically at the end of the startup sequence by
    /// `WealthEngineStartupController`.
    func printSummary() {
        print("[AWC·Startup] ── Startup Trace Summary ─────────────────────────────")
        print(summary)
        print("[AWC·Startup] ─────────────────────────────────────────────────────")
    }
}
