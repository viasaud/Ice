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
        appDelegate.assignAppState(appState)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var appState: AppState?
    private var hasPerformedSetup = false
    private var isWaitingForAccessibilityPermission = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let appState else {
            Logger.appDelegate.warning("Missing app state in applicationWillFinishLaunching")
            return
        }
        appState.setsCursorInBackground = true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let appState else {
            Logger.appDelegate.warning("Missing app state in applicationDidFinishLaunching")
            return
        }

        NSApp.mainMenu?.items.forEach { $0.isHidden = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak appState] in
            guard
                let self,
                let appState,
                !appState.isPreview
            else {
                return
            }
            self.startOrShowPermissions(for: appState)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        appState?.deactivate(withPolicy: .accessory)
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard
            let appState,
            !appState.isPreview
        else {
            return
        }
        appState.permissionsManager.refreshAllPermissions()
        if !appState.permissionsManager.canRunApp {
            startOrShowPermissions(for: appState)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func assignAppState(_ appState: AppState) {
        guard self.appState == nil else {
            Logger.appDelegate.warning("Multiple attempts made to assign app state")
            return
        }
        self.appState = appState
    }

    private func startOrShowPermissions(for appState: AppState) {
        appState.permissionsManager.refreshAllPermissions()
        if appState.permissionsManager.canRunApp {
            performSetupIfNeeded(for: appState)
        } else {
            requestAccessibilityPermissionIfNeeded(for: appState)
        }
    }

    private func performSetupIfNeeded(for appState: AppState) {
        guard !hasPerformedSetup else {
            return
        }
        hasPerformedSetup = true
        appState.performSetup()
    }

    private func requestAccessibilityPermissionIfNeeded(for appState: AppState) {
        guard !isWaitingForAccessibilityPermission else {
            return
        }
        isWaitingForAccessibilityPermission = true
        Task { [weak self, weak appState] in
            guard
                let self,
                let appState
            else {
                return
            }
            await appState.permissionsManager.requestAccessibilityPermissionAndWait()
            isWaitingForAccessibilityPermission = false
            performSetupIfNeeded(for: appState)
        }
    }
}

private extension Logger {
    static let appDelegate = Logger(category: "AppDelegate")
}
