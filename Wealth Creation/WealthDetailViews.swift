import SwiftUI

private var opportunityAuditLabel: String {
#if targetEnvironment(macCatalyst)
    return "Trade Audit"
#else
    return "Decision Line"
#endif
}

private func detailRiskTint(_ label: String) -> Color {
    switch label {
    case "AGGRESSIVE": return WealthTheme.orange
    case "ACTIVE": return WealthTheme.cyan
    case "DEFENSIVE": return WealthTheme.red
    default: return WealthTheme.green
    }
}

private func detailOrderStateTint(_ state: OrderExecutionState) -> Color {
    state.color
}
