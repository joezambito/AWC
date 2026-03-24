import SwiftUI

extension WealthAIStackCatalog {
    static let portfolioGroups: [WealthAIStackGroup] = [
        WealthAIStackGroup(
            title: "PORTFOLIO INTELLIGENCE",
            subtitle: "How the brain manages the whole book instead of only single setups.",
            tint: WealthTheme.green,
            items: [
                WealthAIStackItem(title: "Portfolio Optimizer", note: "Allocate across the best setups while respecting concentration, fees, and mission goals.", status: .foundation),
                WealthAIStackItem(title: "Capital Rotation Planner", note: "Choose what to trim, hold, or add when better setups appear.", status: .foundation),
                WealthAIStackItem(title: "Exposure Balancer", note: "Balance trend, sector, geography, and risk style so the book is not accidentally lopsided.", status: .foundation),
                WealthAIStackItem(title: "Campaign / Goal Alignment Engine", note: "Tie every proposed trade directly back to Daily, Compound, and Mission objectives.", status: .foundation)
            ]
        ),
        WealthAIStackGroup(
            title: "COMPUTE / PLATFORM",
            subtitle: "How the brain spreads work across phone, Mac, and future heavy jobs.",
            tint: WealthTheme.gold,
            items: [
                WealthAIStackItem(title: "Computational Power Layer", note: "Formalize batching, caching, background queues, and heavy-run scheduling.", status: .foundation),
                WealthAIStackItem(title: "Phone Staged Compute", note: "Current phone startup already stages brain work over timed passes.", status: .active),
                WealthAIStackItem(title: "Mac Full Compute", note: "Mac already carries the heavier unrestricted view / control path better than phone.", status: .active),
                WealthAIStackItem(title: "Heavy Backtest / Training Jobs", note: "Reserve large evaluation and retraining workloads for off-phone compute.", status: .foundation),
                WealthAIStackItem(title: "Cloud / Remote Worker Path", note: "Let the heaviest research, backtests, and model jobs move off-device when needed.", status: .foundation),
                WealthAIStackItem(title: "Cache / Snapshot Layer", note: "Store scan results and reusable intermediate features so the phone does not recompute everything every time.", status: .foundation)
            ]
        )
    ]

    static let governanceGroups: [WealthAIStackGroup] = [
        WealthAIStackGroup(
            title: "GOVERNANCE / OVERSIGHT",
            subtitle: "Control, audit, and explainability so the brain stays trustworthy.",
            tint: WealthTheme.gold,
            items: [
                WealthAIStackItem(title: "Model Registry", note: "Track which signal set, ranking logic, and weight profile produced each decision.", status: .foundation),
                WealthAIStackItem(title: "Explainability Layer", note: "Show why the brain ranked, blocked, or rotated a trade in operator-friendly terms.", status: .foundation),
                WealthAIStackItem(title: "Audit / Decision Trail", note: "Keep a full history of scans, promotions, warnings, and execution choices.", status: .foundation),
                WealthAIStackItem(title: "Rollback / Safe Revert", note: "Let the operator revert brain settings or models if a live change behaves badly.", status: .foundation)
            ]
        ),
        WealthAIStackGroup(
            title: "EXTERNAL RESEARCH FEEDS",
            subtitle: "Third-party research and alt-data sources that need real provider access.",
            tint: WealthTheme.purple,
            items: [
                WealthAIStackItem(title: "TIKR", note: "External fundamental / research feed integration requires real provider access.", status: .external),
                WealthAIStackItem(title: "Trade Ideas (HollyAI)", note: "External signal integration requires account/API access and mapping rules.", status: .external),
                WealthAIStackItem(title: "Nansen", note: "External smart-money / on-chain style feed requires provider access.", status: .external),
                WealthAIStackItem(title: "Alternative Data Providers", note: "Job postings, web traffic, app usage, supply-chain, and sentiment feeds can all become extra conviction layers with proper access.", status: .external)
            ]
        )
    ]
}
