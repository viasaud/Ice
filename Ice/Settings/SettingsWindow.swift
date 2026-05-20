//
//  SettingsWindow.swift
//  Ice
//

import SwiftUI

struct SettingsWindow: Scene {
    @ObservedObject var appState: AppState

    var body: some Scene {
        Window(Constants.settingsWindowTitle, id: Constants.settingsWindowID) {
            SettingsView()
                .readWindow { window in
                    guard let window else {
                        return
                    }
                    appState.assignSettingsWindow(window)
                    window.styleMask.insert(.fullSizeContentView)
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    window.toolbarStyle = .unifiedCompact
                    window.isMovableByWindowBackground = true
                }
                .frame(width: 700)
        }
        .commandsRemoved()
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentSize)
        .environmentObject(appState)
        .environmentObject(appState.navigationState)
    }
}
