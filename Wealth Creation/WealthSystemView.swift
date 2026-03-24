import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SystemView: View {
    enum SystemTab: String, CaseIterable, Identifiable {
        case parameters = "System Parameters"
        case brain = "Brain"
        case events = "Event Log"
        case ai = "Brain Control"
        case brokers = "Brokers"
        case help = "Help / Guide"

        var id: String { rawValue }
    }

    @State var tab: SystemTab = .parameters

    var hasDesktopSystemLayout: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }

    var body: some View {
        Group {
            if hasDesktopSystemLayout {
                desktopSystemShell
            } else {
                phoneSystemShell
            }
        }
        .toolbar {
#if !targetEnvironment(macCatalyst)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done", action: dismissSystemKeyboard)
            }
#endif
        }
    }
}

#if canImport(UIKit)
private func dismissSystemKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
#endif
