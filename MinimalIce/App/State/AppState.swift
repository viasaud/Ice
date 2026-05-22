//
//  AppState.swift
//  Ice
//

import Combine
import SwiftUI

/// The model for app-wide state.
@MainActor
final class AppState: ObservableObject {
    /// A Boolean value that indicates whether the active space is fullscreen.
    @Published private(set) var isActiveSpaceFullscreen = WindowServerAdapter.isActiveSpaceFullscreen

    /// Manager for events received by the app.
    private(set) lazy var eventManager = EventManager(appState: self)

    /// Manager for menu bar items.
    private(set) lazy var itemManager = MenuBarItemManager(appState: self)

    /// Manager for the state of the menu bar.
    private(set) lazy var menuBarManager = MenuBarManager(appState: self)

    /// Manager for app permissions.
    private(set) lazy var permissionsManager = PermissionsManager(appState: self)

    /// Manager for the app's settings.
    private(set) lazy var settingsManager = SettingsManager(appState: self)

    /// A Boolean value that indicates whether the "ShowOnHover" feature is prevented.
    private(set) var isShowOnHoverPrevented = false

    /// A Boolean value that indicates whether the app has activated before.
    private var hasActivated = false

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// A Boolean value that indicates whether the app is running as a SwiftUI preview.
    let isPreview: Bool = {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let key = "XCODE_RUNNING_FOR_PREVIEWS"
        return environment[key] != nil
        #else
        return false
        #endif
    }()

    /// A Boolean value that indicates whether the application can set the cursor
    /// in the background.
    var setsCursorInBackground: Bool {
        get { WindowServerAdapter.canSetCursorInBackground }
        set { WindowServerAdapter.canSetCursorInBackground = newValue }
    }

    /// A Boolean value that indicates whether the always-hidden section can be
    /// revealed by a user action.
    var canRevealAlwaysHiddenSection: Bool {
        settingsManager.enableAlwaysHiddenSection
    }

    /// Configures the internal observers for the app state.
    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        Publishers.Merge3(
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
                .mapToVoid(),
            // Frontmost application change can indicate a space change from one display to
            // another, which gets ignored by NSWorkspace.activeSpaceDidChangeNotification.
            NSWorkspace.shared
                .publisher(for: \.frontmostApplication)
                .mapToVoid(),
            // Clicking into a fullscreen space from another space is also ignored.
            UniversalEventMonitor
                .publisher(for: .leftMouseDown)
                .delay(for: 0.1, scheduler: DispatchQueue.main)
                .mapToVoid()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else {
                return
            }
            let isFullscreen = WindowServerAdapter.isActiveSpaceFullscreen
            guard isActiveSpaceFullscreen != isFullscreen else {
                return
            }
            isActiveSpaceFullscreen = isFullscreen
        }
        .store(in: &c)

        forwardObjectWillChange(from: menuBarManager.objectWillChange, storingIn: &c)
        forwardObjectWillChange(from: permissionsManager.objectWillChange, storingIn: &c)
        forwardObjectWillChange(from: settingsManager.objectWillChange, storingIn: &c)

        cancellables = c
    }

    private func forwardObjectWillChange<P: Publisher>(
        from publisher: P,
        storingIn cancellables: inout Set<AnyCancellable>
    ) where P.Output == Void, P.Failure == Never {
        publisher
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// Sets up the app state.
    func performSetup() {
        settingsManager.performSetup()
        configureCancellables()
        permissionsManager.stopAllChecks()
        menuBarManager.performSetup()
        eventManager.performSetup()
        itemManager.performSetup()
    }

    /// Toggles the appropriate menu bar section for the current modifier flags.
    func toggleMenuBarSection(using modifierFlags: NSEvent.ModifierFlags, preferredSection: MenuBarSection? = nil) {
        let sectionName = preferredSection?.name ?? .hidden

        if modifierFlags.contains(.option) {
            guard canRevealAlwaysHiddenSection else {
                return
            }
            menuBarManager.section(withName: .alwaysHidden)?.toggle()
            return
        }

        guard sectionName != .alwaysHidden || canRevealAlwaysHiddenSection else {
            return
        }
        menuBarManager.section(withName: sectionName)?.toggle()
    }

    /// Returns whether a section may be shown during command-drag rearrangement.
    func canShowSectionDuringCommandDrag(_ section: MenuBarSection) -> Bool {
        section.name != .alwaysHidden || canRevealAlwaysHiddenSection
    }

    /// Returns the sections that may appear in a control item's menu.
    func revealableSectionNamesForControlMenu() -> [MenuBarSection.Name] {
        canRevealAlwaysHiddenSection ? [.hidden, .alwaysHidden] : [.hidden]
    }

    /// Activates the app and sets its activation policy to the given value.
    func activate(withPolicy policy: NSApplication.ActivationPolicy) {
        func activateCurrentApplication() {
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                NSRunningApplication.current.activate(from: frontApp)
            } else {
                NSApp.activate()
            }
            NSApp.setActivationPolicy(policy)
        }

        if hasActivated {
            activateCurrentApplication()
        } else {
            hasActivated = true
            Logger.appState.debug("First time activating app, so going through Dock")
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                activateCurrentApplication()
            }
        }
    }

    /// Deactivates the app and sets its activation policy to the given value.
    func deactivate(withPolicy policy: NSApplication.ActivationPolicy) {
        if let nextApp = NSWorkspace.shared.runningApplications.first(where: { $0 != .current }) {
            NSApp.yieldActivation(to: nextApp)
        } else {
            NSApp.deactivate()
        }
        NSApp.setActivationPolicy(policy)
    }

    /// Prevents the "ShowOnHover" feature.
    func preventShowOnHover() {
        isShowOnHoverPrevented = true
    }

    /// Allows the "ShowOnHover" feature.
    func allowShowOnHover() {
        isShowOnHoverPrevented = false
    }
}

// MARK: - Logger
private extension Logger {
    /// The logger to use for the app state.
    static let appState = Logger(category: "AppState")
}
