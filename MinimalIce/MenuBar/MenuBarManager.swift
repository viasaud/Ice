//
//  MenuBarManager.swift
//  Ice
//

@preconcurrency import AXSwift
import Combine
import LaunchAtLogin
import SwiftUI

/// Manager for the state of the menu bar.
@MainActor
final class MenuBarManager: ObservableObject {
    /// A Boolean value that indicates whether the menu bar is either always hidden
    /// by the system, or automatically hidden and shown by the system based on the
    /// location of the mouse.
    @Published private(set) var isMenuBarHiddenBySystem = false

    /// A Boolean value that indicates whether the menu bar is hidden by the system
    /// according to a value stored in UserDefaults.
    @Published private(set) var isMenuBarHiddenBySystemUserDefaults = false

    /// The shared app state.
    private weak var appState: AppState?

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// The managed sections in the menu bar.
    private(set) var sections = [MenuBarSection]()

    /// Initializes a new menu bar manager instance.
    init(appState: AppState) {
        self.appState = appState
    }

    /// Performs the initial setup of the menu bar manager.
    func performSetup() {
        initializeSections()
        configureCancellables()
    }

    /// Performs the initial setup of the menu bar manager's sections.
    private func initializeSections() {
        // Make sure initialization can only happen once.
        guard sections.isEmpty else {
            Logger.menuBarManager.warning("Sections already initialized")
            return
        }

        guard let appState else {
            Logger.menuBarManager.error("Error initializing menu bar sections: Missing app state")
            return
        }

        sections = [
            MenuBarSection(name: .visible, appState: appState),
            MenuBarSection(name: .hidden, appState: appState),
            MenuBarSection(name: .alwaysHidden, appState: appState),
        ]
        sections.forEach { $0.controlItem.refreshStatusItem() }
    }

    /// Configures the internal observers for the manager.
    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        NSApp.publisher(for: \.currentSystemPresentationOptions)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] options in
                guard let self else {
                    return
                }
                let hidden = options.contains(.hideMenuBar) || options.contains(.autoHideMenuBar)
                isMenuBarHiddenBySystem = hidden
            }
            .store(in: &c)

        if
            let hiddenSection = section(withName: .alwaysHidden),
            let window = hiddenSection.controlItem.window
        {
            window.publisher(for: \.frame)
                .map { $0.origin.y }
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard
                        let self,
                        let isMenuBarHidden = Defaults.globalDomain["_HIHideMenuBar"] as? Bool
                    else {
                        return
                    }
                    isMenuBarHiddenBySystemUserDefaults = isMenuBarHidden
                }
                .store(in: &c)
        }

        cancellables = c
    }

    /// Returns a Boolean value that indicates whether the given display
    /// has a valid menu bar.
    func hasValidMenuBar(in windows: [WindowInfo], for display: CGDirectDisplayID) -> Bool {
        guard let menuBarWindow = WindowInfo.getMenuBarWindow(from: windows, for: display) else {
            return false
        }
        let position = menuBarWindow.frame.origin
        do {
            nonisolated(unsafe) let systemElement = systemWideElement
            let uiElement = try systemElement.elementAtPosition(Float(position.x), Float(position.y))
            return try uiElement?.role() == .menuBar
        } catch {
            return false
        }
    }

    /// Returns the frame of the application menu for the given display.
    func getApplicationMenuFrame(for displayID: CGDirectDisplayID) -> CGRect? {
        let displayBounds = CGDisplayBounds(displayID)
        nonisolated(unsafe) let systemElement = systemWideElement

        guard
            let menuBar = try? systemElement.elementAtPosition(Float(displayBounds.origin.x), Float(displayBounds.origin.y)),
            let role = try? menuBar.role(),
            role == .menuBar,
            let items: [UIElement] = try? menuBar.arrayAttribute(.children)?.filter({ (try? $0.attribute(.enabled)) == true })
        else {
            return nil
        }

        let itemFrames = items.lazy.compactMap { try? $0.attribute(.frame) as CGRect? }
        let applicationMenuFrame = itemFrames.reduce(.null, CGRectUnion)

        if applicationMenuFrame.width <= 0 {
            return nil
        }

        // The Accessibility API returns the menu bar for the active screen, regardless of the
        // display origin used. This workaround prevents an incorrect frame from being returned
        // for inactive displays in multi-display setups where one display has a notch.
        if
            let mainScreen = NSScreen.main,
            let thisScreen = NSScreen.screens.first(where: { $0.displayID == displayID }),
            thisScreen != mainScreen,
            let notchedScreen = NSScreen.screens.first(where: { $0.hasNotch }),
            let leftArea = notchedScreen.auxiliaryTopLeftArea,
            applicationMenuFrame.width >= leftArea.maxX
        {
            return nil
        }

        return applicationMenuFrame
    }

    /// Shows the right-click menu.
    func showRightClickMenu(at point: CGPoint) {
        let menu = createMenu()
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu(title: "Minimal Ice")

        let revealModeItem = NSMenuItem(
            title: "Reveal By",
            action: nil,
            keyEquivalent: ""
        )
        revealModeItem.image = MenuItemIcon.reveal
        revealModeItem.submenu = createRevealModeMenu()
        menu.addItem(revealModeItem)

        let sectionDividersItem = NSMenuItem(
            title: "Show Dividers",
            action: #selector(toggleSectionDividers),
            keyEquivalent: ""
        )
        sectionDividersItem.image = MenuItemIcon.dividers
        sectionDividersItem.target = self
        sectionDividersItem.state = appState?.settingsManager.advancedSettingsManager.showSectionDividers == true ? .on : .off
        menu.addItem(sectionDividersItem)

        let alwaysHiddenSectionItem = NSMenuItem(
            title: "Always-Hidden Section",
            action: #selector(toggleAlwaysHiddenSection),
            keyEquivalent: ""
        )
        alwaysHiddenSectionItem.image = MenuItemIcon.alwaysHidden
        alwaysHiddenSectionItem.target = self
        alwaysHiddenSectionItem.state = appState?.settingsManager.advancedSettingsManager.enableAlwaysHiddenSection == true ? .on : .off
        menu.addItem(alwaysHiddenSectionItem)

        let rehideIntervalItem = NSMenuItem(
            title: "Hide After",
            action: nil,
            keyEquivalent: ""
        )
        rehideIntervalItem.image = MenuItemIcon.hideAfter
        rehideIntervalItem.submenu = createRehideIntervalMenu()
        rehideIntervalItem.isEnabled = appState?.settingsManager.hiddenItemsActivationMode == .click
        menu.addItem(rehideIntervalItem)

        menu.addItem(.separator())

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Startup",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.image = MenuItemIcon.launchAtStartup
        launchAtLoginItem.target = self
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let versionItem = NSMenuItem(
            title: "Minimal Ice \(Constants.versionString)",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.image = MenuItemIcon.version
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApp.terminate),
            keyEquivalent: ""
        )
        quitItem.image = MenuItemIcon.quit
        menu.addItem(quitItem)

        return menu
    }

    private func createRevealModeMenu() -> NSMenu {
        let menu = NSMenu(title: "Reveal By")
        let selectedMode = appState?.settingsManager.hiddenItemsActivationMode

        for mode in HiddenItemsActivationMode.allCases {
            let item = NSMenuItem(
                title: mode.menuTitle,
                action: #selector(selectRevealMode),
                keyEquivalent: ""
            )
            item.image = mode.menuIcon
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == selectedMode ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    private func createRehideIntervalMenu() -> NSMenu {
        let menu = NSMenu(title: "Hide After")
        let selectedInterval = appState?.settingsManager.advancedSettingsManager.tempShowInterval

        for interval in Self.rehideIntervals {
            let item = NSMenuItem(
                title: interval.rehideIntervalTitle,
                action: #selector(selectRehideInterval),
                keyEquivalent: ""
            )
            item.image = MenuItemIcon.interval
            item.target = self
            item.representedObject = interval
            item.state = interval == selectedInterval ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    @objc private func selectRevealMode(_ menuItem: NSMenuItem) {
        guard
            let rawValue = menuItem.representedObject as? String,
            let mode = HiddenItemsActivationMode(rawValue: rawValue)
        else {
            return
        }
        appState?.settingsManager.hiddenItemsActivationMode = mode
    }

    @objc private func toggleSectionDividers(_ menuItem: NSMenuItem) {
        guard let manager = appState?.settingsManager.advancedSettingsManager else {
            return
        }
        manager.showSectionDividers.toggle()
        menuItem.state = manager.showSectionDividers ? .on : .off
    }

    @objc private func toggleAlwaysHiddenSection(_ menuItem: NSMenuItem) {
        guard let manager = appState?.settingsManager.advancedSettingsManager else {
            return
        }
        manager.enableAlwaysHiddenSection.toggle()
        menuItem.state = manager.enableAlwaysHiddenSection ? .on : .off
    }

    @objc private func selectRehideInterval(_ menuItem: NSMenuItem) {
        guard let interval = menuItem.representedObject as? TimeInterval else {
            return
        }
        appState?.settingsManager.advancedSettingsManager.tempShowInterval = interval
    }

    @objc private func toggleLaunchAtLogin(_ menuItem: NSMenuItem) {
        LaunchAtLogin.isEnabled.toggle()
        menuItem.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    /// Returns the menu bar section with the given name.
    func section(withName name: MenuBarSection.Name) -> MenuBarSection? {
        sections.first { $0.name == name }
    }
}

// MARK: MenuBarManager: BindingExposable
extension MenuBarManager: BindingExposable { }

private extension MenuBarManager {
    static let rehideIntervals: [TimeInterval] = [0, 5, 10, 15, 20, 30]
}

private extension HiddenItemsActivationMode {
    var menuTitle: String {
        switch self {
        case .click:
            "On Click"
        case .hover:
            "On Hover"
        }
    }

    var menuIcon: NSImage? {
        switch self {
        case .click:
            MenuItemIcon.click
        case .hover:
            MenuItemIcon.hover
        }
    }
}

private extension TimeInterval {
    var rehideIntervalTitle: String {
        self == 0 ? "Immediately" : "\(Int(self)) Seconds"
    }
}

// MARK: - Logger
private extension Logger {
    /// Logger to use for the menu bar manager.
    static let menuBarManager = Logger(category: "MenuBarManager")
}
