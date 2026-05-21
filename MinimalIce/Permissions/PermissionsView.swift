//
//  PermissionsView.swift
//  Ice
//

import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject private var permissionsManager: PermissionsManager
    @Environment(\.openWindow) private var openWindow

    private let contentWidth: CGFloat = 500

    private var accessibilityPermission: Permission {
        permissionsManager.accessibilityPermission
    }

    private var hasAccessibilityPermission: Bool {
        accessibilityPermission.hasPermission
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 24) {
                header
                permissionCard(accessibilityPermission)
                privacyDisclaimer
            }

            actionBar
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(.top, 18)
        .padding(.horizontal, 30)
        .padding(.bottom, 26)
        .background(.windowBackground)
        .preferredColorScheme(.dark)
        .fixedSize()
        .readWindow { window in
            guard let window else {
                return
            }
            window.styleMask.remove([.closable, .miniaturizable])
        }
        .onAppear {
            permissionsManager.refreshAllPermissions()
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 9) {
                Text(verbatim: "$")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)

                Text("access")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            Text("One macOS permission is needed before the app can manage your menu bar.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func permissionCard(_ permission: Permission) -> some View {
        SettingsCard {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(permission.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("Required to find and move menu bar items on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                permissionStatusBadge(permission)
            }
            .frame(minHeight: 28)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func permissionStatusBadge(_ permission: Permission) -> some View {
        if permission.hasPermission {
            TerminalBadge("ALLOWED", tint: .green, fillOpacity: 0.2)
                .accessibilityLabel("Allowed")
        } else {
            TerminalBadge("NEEDED", tint: .orange)
                .accessibilityLabel("Needed")
        }
    }

    @ViewBuilder
    private var privacyDisclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .padding(.top, 1)
                .accessibilityHidden(true)

            Text("Accessibility is used only to manage menu bar items. Everything stays on this Mac; no analytics or telemetry.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack {
            quitButton
            Spacer()
            primaryButton
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var quitButton: some View {
        Button("Quit") {
            NSApp.terminate(nil)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .keyboardShortcut("q", modifiers: .command)
    }

    @ViewBuilder
    private var primaryButton: some View {
        if hasAccessibilityPermission {
            Button("Continue") {
                continueToSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.primary)
            .keyboardShortcut(.defaultAction)
        } else {
            Button("Open Privacy Settings") {
                request(accessibilityPermission)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.primary)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func request(_ permission: Permission) {
        guard let appState = permissionsManager.appState else {
            return
        }

        Task {
            await permissionsManager.requestAccessibilityPermissionAndWait()
            appState.activate(withPolicy: .regular)
            openWindow(id: Constants.permissionsWindowID)
        }
    }

    private func continueToSettings() {
        guard let appState = permissionsManager.appState else {
            return
        }
        appState.lifecycleCoordinator.continueAfterPermissions()
    }
}
