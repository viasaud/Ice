//
//  MinimalIceApp.swift
//  Minimal Ice
//

import SwiftUI

@main
struct MinimalIceApp: App {
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate
    @StateObject private var appState: AppState

    init() {
        let appState = AppState()
        self._appState = StateObject(wrappedValue: appState)
        MigrationManager.migrateAll(appState: appState)
        appDelegate.assignAppState(appState)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
