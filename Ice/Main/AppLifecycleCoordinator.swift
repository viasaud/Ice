//
//  AppLifecycleCoordinator.swift
//  Ice
//

import SwiftUI

/// Coordinates startup, permission gating, and settings window routing.
@MainActor
final class AppLifecycleCoordinator {
    private weak var appState: AppState?
    private var hasPerformedSetup = false

    init(appState: AppState) {
        self.appState = appState
    }

    func finishLaunchingAfterWindowsAreReady() {
        guard let appState else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak appState] in
            guard
                let self,
                let appState,
                !appState.isPreview
            else {
                return
            }
            self.startOrShowPermissions()
        }
    }

    func startOrShowPermissions() {
        guard let appState else {
            return
        }
        appState.permissionsManager.refreshAllPermissions()
        if appState.permissionsManager.canRunApp {
            performSetupIfNeeded()
        } else {
            openPermissionsWindow()
        }
    }

    func openSettingsOrPermissions() {
        guard let appState else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak appState] in
            guard
                let self,
                let appState
            else {
                return
            }
            appState.permissionsManager.refreshAllPermissions()
            if appState.permissionsManager.canRunApp {
                self.performSetupIfNeeded()
                appState.activate(withPolicy: .regular)
                appState.openSettingsWindow()
            } else {
                self.openPermissionsWindow()
            }
        }
    }

    func continueAfterPermissions() {
        guard let appState else {
            return
        }
        performSetupIfNeeded()
        appState.permissionsWindow?.close()
        openSettingsOrPermissions()
    }

    private func performSetupIfNeeded() {
        guard
            let appState,
            !hasPerformedSetup
        else {
            return
        }
        hasPerformedSetup = true
        appState.performSetup()
    }

    private func openPermissionsWindow() {
        guard let appState else {
            return
        }
        appState.activate(withPolicy: .regular)
        appState.dismissSettingsWindow()
        appState.openPermissionsWindow()
    }
}
