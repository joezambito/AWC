import SwiftUI

extension WealthAIStackCatalog {
    static let coreGroups: [WealthAIStackGroup] = [
        WealthAIStackGroup(
            title: "TECHNICAL ENGINE",
            subtitle: "Signal math and chart-state features for the brain.",
            tint: WealthTheme.cyan,
            items: [
                WealthAIStackItem(title: "Relative Strength Index (RSI)", note: "Add oscillator state to short-term score and overbought / oversold control.", status: .foundation),
                WealthAIStackItem(title: "Stochastic Oscillator", note: "Add momentum reversal confirmation and exhaustion checks.", status: .foundation),
                WealthAIStackItem(title: "Moving Averages 15 / 20 / 30 / 50 / 100 / 200", note: "Build stacked trend-state and crossover signals into the ranker.", status: .foundation),
                WealthAIStackItem(title: "Trend Detection", note: "Upgrade the current momentum / sector-flow layer into explicit trend-state logic.", status: .foundation),
                WealthAIStackItem(title: "Volume / Price Discrepancies", note: "Detect unusual price moves versus volume participation and confirm breakouts / failures.", status: .foundation),
                WealthAIStackItem(title: "Cross-Asset Relative Strength", note: "Compare symbols, sectors, indices, FX, and commodities so the brain knows where capital is strongest.", status: .foundation),
                WealthAIStackItem(title: "Volatility Regime Math", note: "Upgrade volatility into explicit expansion, compression, and shock-state awareness.", status: .foundation)
            ]
        ),
        WealthAIStackGroup(
            title: "PATTERN RECOGNITION",
            subtitle: "Structure and reversal logic for tops, bottoms, and continuation patterns.",
            tint: WealthTheme.orange,
            items: [
                WealthAIStackItem(title: "Topping Pattern Detection", note: "Flag exhaustion and weak continuation after fast upside moves.", status: .foundation),
                WealthAIStackItem(title: "Head and Shoulders", note: "Identify reversal structure and feed it into confidence and avoid states.", status: .foundation),
                WealthAIStackItem(title: "Triangles", note: "Track compression, breakout pressure, and false-break risk.", status: .foundation),
                WealthAIStackItem(title: "Double Tops", note: "Use failed second highs to weaken chase signals and lift caution.", status: .foundation),
                WealthAIStackItem(title: "Double Bottoms", note: "Use recovery structure to support controlled reversal entries.", status: .foundation)
            ]
        ),
        WealthAIStackGroup(
            title: "CLUSTERING / ML",
            subtitle: "Feature engineering, model ranking, and behavior-aware learning layers.",
            tint: WealthTheme.green,
            items: [
                WealthAIStackItem(title: "Cluster Algorithms", note: "Group similar setups and regimes so the brain compares like with like.", status: .foundation),
                WealthAIStackItem(title: "Behavioral Clustering", note: "Cluster market behavior, tape behavior, and participant behavior over time.", status: .foundation),
                WealthAIStackItem(title: "Feature Engineering", note: "Normalize technical, flow, catalyst, and risk signals into one structured model input layer.", status: .foundation),
                WealthAIStackItem(title: "Training the Model", note: "Add walk-forward training and score calibration from actual trade outcomes.", status: .foundation),
                WealthAIStackItem(title: "Ranking Management", note: "Current engine already ranks setups and stages scans, but needs deeper ML upgrade.", status: .active),
                WealthAIStackItem(title: "Regime Classification Model", note: "Predict whether the tape is trend, chop, squeeze, panic, or rotation so the whole brain adapts.", status: .foundation),
                WealthAIStackItem(title: "Anomaly Detection", note: "Flag unusual behavior in price, volume, options, broker state, or model output before it hurts capital.", status: .foundation),
                WealthAIStackItem(title: "Online Learning Memory", note: "Let the brain adapt weights from recent real trade outcomes without losing long-term calibration.", status: .foundation)
            ]
        ),
        WealthAIStackGroup(
            title: "DATA INFRASTRUCTURE",
            subtitle: "Pipelines, storage, and dataset management for the brain stack.",
            tint: WealthTheme.blue,
            items: [
                WealthAIStackItem(title: "Data Infrastructure", note: "Real-time ingestion, historical bars, event logs, broker state, and dataset versioning.", status: .foundation),
                WealthAIStackItem(title: "Historical Feature Store", note: "Persist model inputs so the brain can compare current conditions against earlier setups.", status: .foundation),
                WealthAIStackItem(title: "Market Replay / Backtest Dataset", note: "Store snapshots that let the brain replay old sessions exactly instead of guessing from partial history.", status: .foundation),
                WealthAIStackItem(title: "Alternative Data Routing", note: "Formalize where third-party, phone, and Mac-only data slots into one normalized layer.", status: .foundation),
                WealthAIStackItem(title: "Broker State Memory", note: "Keep API state, account state, and execution-state history together with scan history.", status: .foundation)
            ]
        )
    ]
}
