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
    private var isWaitingForAccessibilityPermission = false

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
            requestAccessibilityPermissionIfNeeded()
        }
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

    private func requestAccessibilityPermissionIfNeeded() {
        guard let appState else {
            return
        }
        guard !isWaitingForAccessibilityPermission else {
            return
        }
        isWaitingForAccessibilityPermission = true
        Task { [weak self] in
            guard let self else {
                return
            }
            await appState.permissionsManager.requestAccessibilityPermissionAndWait()
            isWaitingForAccessibilityPermission = false
            performSetupIfNeeded()
        }
    }
}
