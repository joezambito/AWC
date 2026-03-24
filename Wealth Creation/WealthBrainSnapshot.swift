struct WealthBrainSnapshot {
    let mode: WealthAggressionMode
    let hunger: WealthHungerMode
    let regime: WealthMarketRegime
    let targetPressure: String
    let targetPressureValue: Double
    let targetDriver: String
    let capitalDiscipline: String
    let summary: String
    let hottestSymbol: String
    let hottestDecision: String
    let hottestCommand: String
    let rotationSignal: String
    let trustSignal: String
    let trendSignal: String
    let momentumSignal: String
    let patternSignal: String
    let smartMoneySignal: String
    let eventSignal: String
    let anomalySignal: String
    let modelReadiness: String
    let dataReadiness: String

    static let placeholder = WealthBrainSnapshot(
        mode: .moderate,
        hunger: .stalk,
        regime: .balanced,
        targetPressure: "NORMAL TARGET PRESSURE",
        targetPressureValue: 0.35,
        targetDriver: "Daily",
        capitalDiscipline: "DYNAMIC SIZE",
        summary: "Short-term brain waiting for the next clean setup.",
        hottestSymbol: "--",
        hottestDecision: "WAIT",
        hottestCommand: "WAIT FOR EDGE",
        rotationSignal: "NO ROTATION",
        trustSignal: "TRUST FIRST",
        trendSignal: "NEUTRAL",
        momentumSignal: "NEUTRAL",
        patternSignal: "NEUTRAL",
        smartMoneySignal: "NEUTRAL",
        eventSignal: "NEUTRAL",
        anomalySignal: "STABLE",
        modelReadiness: "DEMO READY",
        dataReadiness: "WAITING DATA"
    )
}
