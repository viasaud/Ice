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
        NSSplitViewItem.swizzle()
        MigrationManager.migrateAll(appState: appState)
        appDelegate.assignAppState(appState)
    }

    var body: some Scene {
        SettingsWindow(appState: appState)
        PermissionsWindow(appState: appState)
    }
}
