import SwiftUI

extension MarketsView {
    func toggleRegion(_ region: String) {
        if expandedRegions.contains(region) {
            expandedRegions.remove(region)
        } else {
            expandedRegions.insert(region)
        }
    }

    func toggleSymbol(_ symbol: String) {
        if expandedSymbols.contains(symbol) {
            expandedSymbols.remove(symbol)
        } else {
            expandedSymbols.insert(symbol)
        }
    }

    func marketUniverseTint(for blueprint: OpportunityBlueprint) -> Color {
        switch blueprint.dataQualityLabel.uppercased() {
        case "FRESH":
            return blueprint.risk <= 30 ? WealthTheme.green : WealthTheme.blue
        case "AGING":
            return WealthTheme.orange
        default:
            return WealthTheme.red
        }
    }
}
