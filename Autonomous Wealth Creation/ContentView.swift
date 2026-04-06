//
//  ContentView.swift
//  Autonomous Wealth Creation
//
//  Created by Joe Zambito on 6/4/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authStore = WealthAuthStore.shared
    @AppStorage("awc_root_is_unlocked") private var isUnlocked = false
    @State private var launchPrepared = false

    var body: some View {
        Group {
            if isUnlocked {
                WealthUnlockedRootHost()
                    .environmentObject(authStore)
            } else {
                WealthLockView()
                    .environmentObject(authStore)
            }
        }
        .task {
            guard !launchPrepared else { return }
            launchPrepared = true
            WealthAppSessionController.shared.prepareLaunch(isUnlocked: $isUnlocked)
        }
        .onChange(of: isUnlocked) { _, unlocked in
            WealthAppSessionController.shared.syncSession(unlocked: unlocked, phase: scenePhase)
        }
        .onChange(of: scenePhase) { _, newPhase in
            WealthAppSessionController.shared.handlePhaseChange(newPhase, isUnlocked: $isUnlocked)
        }
    }
}
