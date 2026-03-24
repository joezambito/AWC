import SwiftUI

extension WealthAIStackCatalog {
    static let intelligenceGroups: [WealthAIStackGroup] = [
        WealthAIStackGroup(
            title: "SMART MONEY / INSTITUTIONAL",
            subtitle: "Signal sources for options, dark pools, insider activity, and fund footprints.",
            tint: WealthTheme.purple,
            items: [
                WealthAIStackItem(title: "Options Flow", note: "Elevate unusual options activity from label-only intel into live weighted signal input.", status: .foundation),
                WealthAIStackItem(title: "Dark Pool Data", note: "Turn dark-pool prints into accumulation / distribution pressure inside the score engine.", status: .foundation),
                WealthAIStackItem(title: "13F Filing Analysis", note: "Track institutional position shifts and feed longer-cycle conviction.", status: .foundation),
                WealthAIStackItem(title: "Insider Monitoring", note: "Add insider buy / sell behavior to trust and catalyst state.", status: .foundation),
                WealthAIStackItem(title: "Predicting Active Fund Trades", note: "Infer likely fund rotation using sector, filings, and flow behavior.", status: .foundation),
                WealthAIStackItem(title: "Smart Money Divergence", note: "Detect when dark-pool / options behavior disagrees with price and use it as a high-value caution or accumulation clue.", status: .foundation)
            ]
        ),
        WealthAIStackGroup(
            title: "EVENT / NLP INTELLIGENCE",
            subtitle: "Calendar, text, and catalyst understanding beyond simple labels.",
            tint: WealthTheme.blue,
            items: [
                WealthAIStackItem(title: "News NLP", note: "Turn headlines and article text into directional catalyst, severity, and confidence signals.", status: .foundation),
                WealthAIStackItem(title: "Transcript Intelligence", note: "Score earnings calls, presentations, and management language shifts.", status: .foundation),
                WealthAIStackItem(title: "Event Calendar Engine", note: "Track earnings, macro releases, product events, and regulatory dates as explicit risk and opportunity drivers.", status: .foundation),
                WealthAIStackItem(title: "Catalyst Decay Model", note: "Measure how fast a catalyst edge is fading so late entries get penalized.", status: .foundation),
                WealthAIStackItem(title: "Narrative Shift Detection", note: "Catch when the market story changes before price fully reflects it.", status: .foundation)
            ]
        ),
        WealthAIStackGroup(
            title: "EXECUTION INTELLIGENCE",
            subtitle: "Order placement, route choice, and adaptive execution behavior.",
            tint: WealthTheme.orange,
            items: [
                WealthAIStackItem(title: "Order Type Selection", note: "Choose market, limit, staged, or wait behavior from setup and liquidity context.", status: .foundation),
                WealthAIStackItem(title: "Broker Route Selection", note: "Use broker trust, fees, and route suitability to steer execution choices.", status: .foundation),
                WealthAIStackItem(title: "Cancel / Replace Logic", note: "Let the brain repair its own orders when price moves or timing windows change.", status: .foundation),
                WealthAIStackItem(title: "Execution Slippage Tracker", note: "Measure expected versus actual fill quality and feed that back into route trust.", status: .foundation),
                WealthAIStackItem(title: "Multi-Leg Coordination", note: "Coordinate entries, exits, and profit-protection actions as a single execution plan.", status: .foundation)
            ]
        ),
        WealthAIStackGroup(
            title: "RISK SYSTEMS",
            subtitle: "Protection, sizing, concentration, and survival controls.",
            tint: WealthTheme.red,
            items: [
                WealthAIStackItem(title: "Risk Management System", note: "Current app already has kill switch, shield, profit lock, floor, surge, and dynamic sizing.", status: .active),
                WealthAIStackItem(title: "Correlation / Concentration Controls", note: "Extend current sector stacking checks into fuller portfolio-risk control.", status: .foundation),
                WealthAIStackItem(title: "Liquidity / Slippage Controls", note: "Add tradeability checks before promotion to live-ready setups.", status: .foundation),
                WealthAIStackItem(title: "Execution Safety Layer", note: "Turn manual readiness rules into a fuller automated pre-trade safety engine.", status: .foundation),
                WealthAIStackItem(title: "Portfolio Heat Map", note: "Track how much live risk is concentrated by sector, style, theme, and regime.", status: .foundation),
                WealthAIStackItem(title: "Tail-Risk Overrides", note: "Force defensive behavior during panic, gap, or event-shock conditions.", status: .foundation)
            ]
        )
    ]
}
