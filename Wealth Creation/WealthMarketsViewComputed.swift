import SwiftUI

extension MarketsView {
    var hasDesktopLayout: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }

    var preferredRegionOrder: [String] {
        ["US", "CA", "EU", "APAC", "ME", "LATAM", "AFRICA", "AU", "FX", "CRYPTO", "GLOBAL", "UNKNOWN"]
    }

    var marketToggles: [(String, Binding<Bool>, Color)] {
        [
            ("US", $scanUS, WealthTheme.cyan),
            ("ASX", $scanASX, WealthTheme.green),
            ("CAN", $scanCanada, WealthTheme.blue),
            ("EU/UK", $scanEurope, WealthTheme.purple),
            ("ASIA", $scanAsia, WealthTheme.orange),
            ("ME", $scanMiddleEast, WealthTheme.green),
            ("RUS", $scanRussia, WealthTheme.purple),
            ("LATAM", $scanLatam, WealthTheme.orange),
            ("AFR", $scanAfrica, WealthTheme.cyan),
            ("FX", $scanFX, WealthTheme.blue),
            ("CRYPTO", $scanCrypto, WealthTheme.orange),
            ("COM", $scanCommodities, WealthTheme.red)
        ]
    }

    var themeToggles: [(String, Binding<Bool>, Color)] {
        [
            ("DEFENSE", $themeDefense, WealthTheme.purple),
            ("MINERS", $themeMiners, WealthTheme.orange),
            ("CATALYST", $themeCatalysts, WealthTheme.green),
            ("EARNINGS", $themeEarnings, WealthTheme.cyan),
            ("SMART S", $themeSmartMoney, WealthTheme.blue),
            ("MOMENTUM", $themeMomentum, WealthTheme.red)
        ]
    }
}

func marketUniverseTint(forMarket market: String) -> Color {
    switch WealthMarketLabels.region(for: market) {
    case "US": return WealthTheme.cyan
    case "AU": return WealthTheme.green
    case "CA": return WealthTheme.blue
    case "EU": return WealthTheme.purple
    case "APAC": return WealthTheme.orange
    case "ME": return WealthTheme.gold
    case "LATAM": return WealthTheme.orange
    case "AFRICA": return WealthTheme.cyan
    case "FX": return WealthTheme.blue
    case "CRYPTO": return WealthTheme.orange
    default: return WealthTheme.white
    }
}
