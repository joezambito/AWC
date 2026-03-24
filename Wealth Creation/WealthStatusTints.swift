import SwiftUI

func riskTint(_ label: String) -> Color {
    switch label {
    case "AGGRESSIVE":
        return WealthTheme.orange
    case "ACTIVE":
        return WealthTheme.cyan
    case "DEFENSIVE":
        return WealthTheme.red
    default:
        return WealthTheme.green
    }
}

func orderStateTint(_ state: OrderExecutionState) -> Color {
    state.color
}
