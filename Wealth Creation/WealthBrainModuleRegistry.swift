import Foundation

// MARK: - WealthBrainModuleProtocol

/// A discrete unit of brain logic that can be registered with
/// `WealthBrainModuleRegistry` and invoked during each scan cycle.
///
/// Modules are passive observers: they receive the current opportunity
/// snapshot and may update their own internal state, but they do NOT
/// mutate the opportunities directly.  Score adjustments are applied
/// by `WealthBrainStore.bias()` after all modules have been consulted.
protocol WealthBrainModuleProtocol: AnyObject {
    /// A short human-readable label used in event-log entries.
    var moduleName: String { get }

    /// Called once per scan cycle with the current ranked universe.
    ///
    /// - Parameters:
    ///   - opportunities: Full ranked universe as of this cycle.
    ///   - stage: Scan stage within the current cycle (0–5).
    func process(opportunities: [Opportunity], stage: Int)
}

// MARK: - WealthBrainModuleRegistry

/// Maintains the set of active brain modules and fans scan-cycle events
/// out to each registered module.
///
/// Registration is additive: modules are registered once at app start (via
/// `WealthNewComponentsBootstrap`) and remain active for the lifetime of the
/// process.  No existing logic in `WealthBrainStore` is modified; the
/// registry is an opt-in extension point.
@MainActor
final class WealthBrainModuleRegistry {

    // MARK: Shared instance

    static let shared = WealthBrainModuleRegistry()
    private init() {}

    // MARK: - State

    private var modules: [any WealthBrainModuleProtocol] = []

    // MARK: - Registration

    /// Register a module to receive scan-cycle events.
    ///
    /// - Parameter module: The module to add.  Duplicate registrations are
    ///   silently ignored (comparison is by object identity).
    func register(_ module: any WealthBrainModuleProtocol) {
        guard !modules.contains(where: { $0 === module }) else { return }
        modules.append(module)

        WealthEventLogStore.shared.record(
            title: "Brain Module Registry",
            detail: "Registered module: \(module.moduleName) — total: \(modules.count).",
            category: "brain",
            tintName: "blue",
            timestamp: .now
        )
    }

    /// Remove a previously-registered module.
    ///
    /// - Parameter module: The module to remove.
    func unregister(_ module: any WealthBrainModuleProtocol) {
        modules.removeAll { $0 === module }
    }

    // MARK: - Dispatch

    /// Dispatch the current scan snapshot to all registered modules.
    ///
    /// Called by `WealthBrainStore.ingest()` after the primary `learn()`
    /// pass so that individual modules can update their internal state.
    ///
    /// - Parameters:
    ///   - opportunities: Full ranked universe as of this cycle.
    ///   - stage: Scan stage within the current cycle (0–5).
    func dispatch(opportunities: [Opportunity], stage: Int) {
        guard !modules.isEmpty else { return }

        for module in modules {
            module.process(opportunities: opportunities, stage: stage)
        }

        WealthEventLogStore.shared.record(
            title: "Brain Module Registry",
            detail: "Dispatched stage=\(stage) to \(modules.count) module(s).",
            category: "brain",
            tintName: "green",
            timestamp: .now
        )
    }

    // MARK: - Queries

    /// Number of currently-registered modules.
    var moduleCount: Int { modules.count }

    /// Names of all registered modules, in registration order.
    var moduleNames: [String] { modules.map(\.moduleName) }
}
