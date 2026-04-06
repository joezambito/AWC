import SwiftUI

enum WealthSimulatorSessionSupport {
    static func unlockIfSupported(_ isUnlocked: Binding<Bool>) -> Bool {
        guard shouldAutoUnlock else { return false }
        isUnlocked.wrappedValue = true
        return true
    }

    static var defaultRootTab: MainTab {
        .dashboard
    }

    private static var shouldAutoUnlock: Bool {
#if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }
}
