import SwiftUI

func wealthConfidenceTint(_ confidence: Int) -> Color {
    switch confidence {
    case 80...100: return WealthTheme.green
    case 60...70: return WealthTheme.blue
    case 1...29: return WealthTheme.red
    default: return WealthTheme.purple
    }
}

func wealthHoldingConfidenceTint(_ confidence: Int) -> Color {
    confidence >= 80 ? WealthTheme.green : WealthTheme.gold
}

func wealthScoreTint(_ score: Int) -> Color {
    switch score {
    case 1...20: return WealthTheme.green
    case 21...29: return WealthTheme.blue
    case 60...100: return WealthTheme.red
    default: return WealthTheme.purple
    }
}

func wealthHasGreenSignalBands(score: Int, confidence: Int) -> Bool {
    wealthScoreTint(score) == WealthTheme.green && wealthConfidenceTint(confidence) == WealthTheme.green
}

func wealthHasBlueSignalBands(score: Int, confidence: Int) -> Bool {
    wealthScoreTint(score) == WealthTheme.blue && wealthConfidenceTint(confidence) == WealthTheme.blue
}

func wealthHasRedSignalBands(score: Int, confidence: Int) -> Bool {
    _ = confidence
    return wealthScoreTint(score) == WealthTheme.red
}

func wealthBuyReady(score: Int, confidence: Int) -> Bool {
    wealthHasGreenSignalBands(score: score, confidence: confidence)
}

func wealthCardSignalTint(score: Int, confidence: Int) -> Color {
    if wealthHasBlueSignalBands(score: score, confidence: confidence) {
        return WealthTheme.blue
    }
    if wealthHasRedSignalBands(score: score, confidence: confidence) {
        return WealthTheme.red
    }
    return WealthTheme.purple
}

func wealthScoreBandGuideRows() -> [String] {
    [
        "1-20 = GREEN",
        "21-29 = BLUE",
        "30-59 = PURPLE",
        "60-100 = RED",
        "Lower score is stronger"
    ]
}

func wealthConfidenceBandGuideRows() -> [String] {
    [
        "80-100 = GREEN",
        "60-70 = BLUE",
        "30-59 and 71-79 = PURPLE",
        "1-29 = RED"
    ]
}
