//
//  PermissionsWindow.swift
//  Ice
//

import SwiftUI

struct PermissionsWindow: Scene {
    @ObservedObject var appState: AppState

    var body: some Scene {
        Window(Constants.permissionsWindowTitle, id: Constants.permissionsWindowID) {
            PermissionsView()
                .readWindow { window in
                    guard let window else {
                        return
                    }
                    appState.assignPermissionsWindow(window)
                    window.styleMask.insert(.fullSizeContentView)
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    window.toolbarStyle = .unifiedCompact
                    window.isMovableByWindowBackground = true
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .environmentObject(appState.permissionsManager)
    }
}
