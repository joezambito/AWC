import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum WealthTheme {
    static let backgroundTop = Color(red: 0.01, green: 0.06, blue: 0.13)
    static let backgroundMid = Color(red: 0.03, green: 0.05, blue: 0.16)
    static let backgroundBottom = Color(red: 0.12, green: 0.03, blue: 0.20)

    static let cyan = Color(red: 0.15, green: 0.86, blue: 0.97)
    static let blue = Color(red: 0.12, green: 0.63, blue: 1.00)
    static let green = Color(red: 0.21, green: 0.95, blue: 0.35)
    static let purple = Color(red: 0.74, green: 0.39, blue: 0.98)
    static let orange = Color(red: 1.00, green: 0.60, blue: 0.16)
    static let gold = Color(red: 1.00, green: 0.83, blue: 0.24)
    static let yellow = Color(red: 1.00, green: 0.92, blue: 0.18)
    static let grey = Color(red: 0.60, green: 0.64, blue: 0.72)
    static let silverLight = Color(red: 0.72, green: 0.72, blue: 0.75)
    static let silverDark = Color(red: 0.42, green: 0.42, blue: 0.46)
    static let red = Color(red: 1.00, green: 0.26, blue: 0.37)
    static let white = Color.white

    static var silver: Color {
#if canImport(UIKit)
        Color(
            uiColor: UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(red: 0.42, green: 0.42, blue: 0.46, alpha: 1.0)
                } else {
                    return UIColor(red: 0.72, green: 0.72, blue: 0.75, alpha: 1.0)
                }
            }
        )
#else
        silverDark
#endif
    }

    static let cardFill = Color(red: 0.05, green: 0.08, blue: 0.14).opacity(0.78)
    static let cardStroke = Color.white.opacity(0.11)

    static let background = LinearGradient(
        colors: [backgroundTop, backgroundMid, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
