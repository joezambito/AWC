import SwiftUI

func wealthConfidenceTint(_ confidence: Int) -> Color {
    switch confidence {
    case 80...100: return WealthTheme.green
    case 60...79: return WealthTheme.blue
    case 30...59: return WealthTheme.orange
    default: return WealthTheme.red
    }
}

func wealthHoldingConfidenceTint(_ confidence: Int) -> Color {
    confidence >= 80 ? WealthTheme.green : WealthTheme.gold
}

func wealthScoreTint(_ score: Int) -> Color {
    switch score {
    case 1...20: return WealthTheme.green
    case 21...39: return WealthTheme.blue
    case 40...59: return WealthTheme.orange
    default: return WealthTheme.red
    }
}

func wealthBuyReady(score: Int, confidence: Int) -> Bool {
    wealthScoreTint(score) == WealthTheme.green && wealthConfidenceTint(confidence) == WealthTheme.green
}

func wealthCardSignalTint(score: Int, confidence: Int) -> Color {
    let scoreTint = wealthScoreTint(score)
    let confidenceTint = wealthConfidenceTint(confidence)
    return scoreTint == confidenceTint ? scoreTint : WealthTheme.purple
}

func wealthScoreBandGuideRows() -> [String] {
    [
        "1-20 = GREEN",
        "21-39 = BLUE",
        "40-59 = ORANGE",
        "60-100 = RED",
        "Lower score is stronger"
    ]
}

func wealthConfidenceBandGuideRows() -> [String] {
    [
        "80-100 = GREEN",
        "60-79 = BLUE",
        "30-59 = ORANGE",
        "1-29 = RED"
    ]
}
