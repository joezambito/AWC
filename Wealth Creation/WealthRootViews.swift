import SwiftUI

// MARK: - WealthUnlockedRootHost
//
// Root view shown when the app is unlocked (authenticated).
// The real implementation lives in the Xcode project.

struct WealthUnlockedRootHost: View {
    @EnvironmentObject private var authStore: WealthAuthStore

    var body: some View {
        EmptyView()
    }
}

// MARK: - WealthLockView
//
// Lock/authentication screen shown when the app is locked.
// The real implementation lives in the Xcode project.

struct WealthLockView: View {
    @EnvironmentObject private var authStore: WealthAuthStore

    var body: some View {
        EmptyView()
    }
}
