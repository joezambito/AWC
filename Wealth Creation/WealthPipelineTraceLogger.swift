import Foundation
import SwiftUI

enum WealthPipelineTraceLogger {
    private static let enabledKey = "awc_pipeline_trace_enabled"

    private enum RegionBucket: String, CaseIterable {
        case au = "AU"
        case us = "US"
        case eu = "EU"
        case other = "Other"
    }

    private enum ColorBucket: String, CaseIterable {
        case green = "Green"
        case blue = "Blue"
        case purple = "Purple"
        case red = "Red"
    }

    #if DEBUG
    static var isEnabledForDebugOutput: Bool {
        isEnabled
    }

    private static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: enabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: enabledKey)
    }

    static func log(stage: String, blueprints: [OpportunityBlueprint]) {
        guard isEnabled else { return }
        NSLog(
            "[PipelineTrace] stage=%@ total=%ld regions=%@ markets=%@ colors={Green:0,Blue:0,Purple:0,Red:0} note=preopportunity",
            stage,
            blueprints.count,
            regionSummary(for: blueprints.map(\.market)),
            marketSummary(for: blueprints.map(\.market))
        )
    }

    static func log(stage: String, opportunities: [Opportunity]) {
        guard isEnabled else { return }
        NSLog(
            "[PipelineTrace] stage=%@ total=%ld regions=%@ markets=%@ colors=%@",
            stage,
            opportunities.count,
            regionSummary(for: opportunities.map(\.market)),
            marketSummary(for: opportunities.map(\.market)),
            colorSummary(for: opportunities)
        )
    }

    static func logUniverse(_ blueprints: [OpportunityBlueprint]) {
        guard isEnabled else { return }
        NSLog(
            "[PipelineTrace] universe total=%ld regions=%@ markets=%@",
            blueprints.count,
            regionSummary(for: blueprints.map(\.market)),
            marketSummary(for: blueprints.map(\.market))
        )
    }

    static func logSymbolTrace(rawBrokerSymbols: Int, rawQuoteSymbols: Int) {
        guard isEnabled else { return }
        NSLog("[SymbolTrace] rawBrokerSymbols total=%ld", rawBrokerSymbols)
        NSLog("[SymbolTrace] rawQuoteSymbols total=%ld", rawQuoteSymbols)
    }

    static func logSeedUniverse(_ blueprints: [OpportunityBlueprint]) {
        guard isEnabled else { return }
        NSLog(
            "[PipelineTrace] seedUniverse total=%ld regions=%@ markets=%@",
            blueprints.count,
            regionSummary(for: blueprints.map(\.market)),
            marketSummary(for: blueprints.map(\.market))
        )
    }

    static func logExpandedUniverse(
        total: Int,
        dropped: Int,
        markets: [String]
    ) {
        guard isEnabled else { return }
        NSLog(
            "[PipelineTrace] expandedUniverse total=%ld dropped=%ld regions=%@ markets=%@",
            total,
            dropped,
            regionSummary(for: markets),
            marketSummary(for: markets)
        )
    }

    static func logStaged(
        total: Int,
        dropped: Int,
        blueprints: [OpportunityBlueprint],
        scannedMarkets: Set<String>,
        protectedKeys: Set<String>
    ) {
        guard isEnabled else { return }
        NSLog(
            "[PipelineTrace] staged total=%ld dropped=%ld regions=%@ markets=%@ scannedMarkets=%ld protected=%ld",
            total,
            dropped,
            regionSummary(for: blueprints.map(\.market)),
            marketSummary(for: blueprints.map(\.market)),
            scannedMarkets.count,
            protectedKeys.count
        )
    }

    static func logBuilt(
        total: Int,
        dropped: Int,
        opportunities: [Opportunity]
    ) {
        guard isEnabled else { return }
        NSLog(
            "[PipelineTrace] built total=%ld dropped=%ld regions=%@ markets=%@ colors=%@",
            total,
            dropped,
            regionSummary(for: opportunities.map(\.market)),
            marketSummary(for: opportunities.map(\.market)),
            colorSummary(for: opportunities)
        )
    }
    #else
    static var isEnabledForDebugOutput: Bool { false }
    static func log(stage: String, blueprints: [OpportunityBlueprint]) {}
    static func log(stage: String, opportunities: [Opportunity]) {}
    static func logSymbolTrace(rawBrokerSymbols: Int, rawQuoteSymbols: Int) {}
    static func logSeedUniverse(_ blueprints: [OpportunityBlueprint]) {}
    static func logExpandedUniverse(total: Int, dropped: Int, markets: [String]) {}
    static func logUniverse(_ blueprints: [OpportunityBlueprint]) {}
    static func logStaged(total: Int, dropped: Int, blueprints: [OpportunityBlueprint], scannedMarkets: Set<String>, protectedKeys: Set<String>) {}
    static func logBuilt(total: Int, dropped: Int, opportunities: [Opportunity]) {}
    #endif

    private static func regionSummary(for markets: [String]) -> String {
        let counts = markets.reduce(into: [RegionBucket: Int]()) { partial, market in
            partial[regionBucket(for: market), default: 0] += 1
        }

        let parts = RegionBucket.allCases.map { bucket in
            "\(bucket.rawValue):\(counts[bucket, default: 0])"
        }
        return "{\(parts.joined(separator: ","))}"
    }

    private static func marketSummary(for markets: [String]) -> String {
        let counts = markets.reduce(into: [String: Int]()) { partial, market in
            partial[market, default: 0] += 1
        }

        let parts = counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(12)
            .map { "\($0.key):\($0.value)" }

        return "{\(parts.joined(separator: ","))}"
    }

    private static func colorSummary(for opportunities: [Opportunity]) -> String {
        let counts = opportunities.reduce(into: [ColorBucket: Int]()) { partial, opportunity in
            partial[colorBucket(for: opportunity), default: 0] += 1
        }

        let parts = ColorBucket.allCases.map { bucket in
            "\(bucket.rawValue):\(counts[bucket, default: 0])"
        }
        return "{\(parts.joined(separator: ","))}"
    }

    private static func regionBucket(for market: String) -> RegionBucket {
        switch WealthMarketLabels.region(for: market) {
        case "AU":
            return .au
        case "US":
            return .us
        case "EU":
            return .eu
        default:
            return .other
        }
    }

    private static func colorBucket(for opportunity: Opportunity) -> ColorBucket {
        switch opportunity.cardSignalTint {
        case WealthTheme.green:
            return .green
        case WealthTheme.blue:
            return .blue
        case WealthTheme.red:
            return .red
        default:
            return .purple
        }
    }
}
