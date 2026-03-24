import SwiftUI

extension SystemView {
    @ViewBuilder
    var activeSystemView: some View {
        switch tab {
        case .parameters:
            WealthSystemParametersSection(hasDesktopSystemLayout: hasDesktopSystemLayout)
        case .brain:
            WealthSystemBrainSection(hasDesktopSystemLayout: hasDesktopSystemLayout)
        case .events:
            WealthSystemEventLogSection()
        case .ai:
            WealthSystemAISection(hasDesktopSystemLayout: hasDesktopSystemLayout)
        case .brokers:
            if hasDesktopSystemLayout {
                WealthSystemDesktopBrokerSection()
            } else {
                WealthPhoneBrokerSection()
            }
        case .help:
            WealthSystemHelpSection(hasDesktopSystemLayout: hasDesktopSystemLayout)
        }
    }
}
