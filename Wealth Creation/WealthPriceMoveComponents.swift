import SwiftUI

func wealthPercentMoveText(_ value: Double) -> String {
    value >= 0 ? "+\(WealthFormat.percent(value))" : WealthFormat.percent(value)
}

func wealthPercentMoveTint(_ value: Double) -> Color {
    value >= 0 ? WealthTheme.green : WealthTheme.red
}

func percentMoveInfoCell(_ value: Double, label: String = "%") -> some View {
    infoCell(label: label, value: wealthPercentMoveText(value), tint: wealthPercentMoveTint(value))
}

func wealthNetExitTint(netExit: Double, buyTotal: Double) -> Color {
    if netExit > buyTotal { return WealthTheme.green }
    if netExit < buyTotal { return WealthTheme.red }
    return WealthTheme.orange
}

func wealthPnLTint(_ value: Double) -> Color {
    if value < 0 { return WealthTheme.red }
    if value > 0 { return WealthTheme.green }
    return WealthTheme.orange
}

func wealthRelativeTint(current: Double, baseline: Double) -> Color {
    if current > baseline { return WealthTheme.green }
    if current < baseline { return WealthTheme.red }
    return WealthTheme.orange
}

func wealthPnLText(_ value: Double) -> String {
    value > 0 ? "+\(WealthFormat.money(value))" : WealthFormat.money(value)
}

func wealthPnLText(_ value: Double, prefixPositive: String) -> String {
    value > 0 ? "\(prefixPositive)+\(WealthFormat.money(value))" : "\(prefixPositive)\(WealthFormat.money(value))"
}
