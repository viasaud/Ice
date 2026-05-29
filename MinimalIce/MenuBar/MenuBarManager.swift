//
//  MenuBarManager.swift
//  Ice
//

import ApplicationServices
import Combine
import ServiceManagement
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
    private var sectionsByName = [MenuBarSection.Name: MenuBarSection]()

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

        let initializedSections = [
            MenuBarSection(name: .visible, appState: appState),
            MenuBarSection(name: .hidden, appState: appState),
            MenuBarSection(name: .alwaysHidden, appState: appState),
        ]
        sections = initializedSections
        sectionsByName = Dictionary(
            uniqueKeysWithValues: initializedSections.map { ($0.name, $0) }
        )
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
                setMenuBarHiddenBySystem(hidden)
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
                    setMenuBarHiddenBySystemUserDefaults(isMenuBarHidden)
                }
                .store(in: &c)
        }

        cancellables = c
    }

    private func setMenuBarHiddenBySystem(_ hidden: Bool) {
        guard isMenuBarHiddenBySystem != hidden else {
            return
        }
        isMenuBarHiddenBySystem = hidden
    }

    private func setMenuBarHiddenBySystemUserDefaults(_ hidden: Bool) {
        guard isMenuBarHiddenBySystemUserDefaults != hidden else {
            return
        }
        isMenuBarHiddenBySystemUserDefaults = hidden
    }

    /// Returns the frame of the application menu for the given display.
    func getApplicationMenuFrame(for displayID: CGDirectDisplayID) -> CGRect? {
        let displayBounds = CGDisplayBounds(displayID)

        guard
            let menuBar = AXUIElement.menuBar(at: displayBounds.origin),
            let items = menuBar.enabledChildren
        else {
            return nil
        }

        let itemFrames = items.lazy.compactMap(\.frame)
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

    func createMenu() -> NSMenu {
        let menu = NSMenu(title: "Minimal Ice")

        let revealModeItem = NSMenuItem(
            title: "Reveal By",
            action: nil,
            keyEquivalent: ""
        )
        revealModeItem.image = .menuIcon("eye")
        revealModeItem.submenu = createRevealModeMenu()
        menu.addItem(revealModeItem)

        let alwaysHiddenSectionItem = NSMenuItem(
            title: "Always-Hidden Section",
            action: #selector(toggleAlwaysHiddenSection),
            keyEquivalent: ""
        )
        alwaysHiddenSectionItem.image = .menuIcon("eye.slash")
        alwaysHiddenSectionItem.target = self
        alwaysHiddenSectionItem.state = appState?.settingsManager.enableAlwaysHiddenSection == true ? .on : .off
        menu.addItem(alwaysHiddenSectionItem)

        let rehideIntervalItem = NSMenuItem(
            title: "Hide After",
            action: nil,
            keyEquivalent: ""
        )
        rehideIntervalItem.image = .menuIcon("timer")
        rehideIntervalItem.submenu = createRehideIntervalMenu()
        rehideIntervalItem.isEnabled = appState?.settingsManager.hiddenItemsActivationMode == .click
        menu.addItem(rehideIntervalItem)

        menu.addItem(.separator())

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Startup",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.image = .menuIcon("play.circle")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = SMAppService.mainApp.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let versionItem = NSMenuItem(
            title: "Minimal Ice \(Constants.versionString)",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.image = .menuIcon("info.circle")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApp.terminate),
            keyEquivalent: ""
        )
        quitItem.image = .menuIcon("power")
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
        let selectedInterval = appState?.settingsManager.tempShowInterval

        for interval in Self.rehideIntervals {
            let item = NSMenuItem(
                title: interval.rehideIntervalTitle,
                action: #selector(selectRehideInterval),
                keyEquivalent: ""
            )
            item.image = .menuIcon("clock")
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
        appState?.settingsManager.setHiddenItemsActivationMode(mode)
    }

    @objc private func toggleAlwaysHiddenSection(_ menuItem: NSMenuItem) {
        guard let manager = appState?.settingsManager else {
            return
        }
        manager.toggleAlwaysHiddenSection()
        menuItem.state = manager.enableAlwaysHiddenSection ? .on : .off
    }

    @objc private func selectRehideInterval(_ menuItem: NSMenuItem) {
        guard let interval = menuItem.representedObject as? TimeInterval else {
            return
        }
        appState?.settingsManager.setTempShowInterval(interval)
    }

    @objc private func toggleLaunchAtLogin(_ menuItem: NSMenuItem) {
        do {
            if SMAppService.mainApp.isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            menuItem.state = SMAppService.mainApp.isEnabled ? .on : .off
        } catch {
            Logger.menuBarManager.error("Failed to toggle launch at startup: \(error)")
        }
    }

    /// Returns the menu bar section with the given name.
    func section(withName name: MenuBarSection.Name) -> MenuBarSection? {
        sectionsByName[name]
    }
}

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
            .menuIcon("cursorarrow.click")
        case .hover:
            .menuIcon("hand.point.up.left")
        }
    }
}

private extension TimeInterval {
    var rehideIntervalTitle: String {
        self == 0 ? "Immediately" : "\(Int(self)) Seconds"
    }
}

private extension NSImage {
    static func menuIcon(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }
}

private extension SMAppService {
    var isEnabled: Bool {
        status == .enabled
    }
}

private extension AXUIElement {
    static func menuBar(at point: CGPoint) -> AXUIElement? {
        let systemElement = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemElement, Float(point.x), Float(point.y), &element) == .success else {
            return nil
        }
        guard element?.role == kAXMenuBarRole else {
            return nil
        }
        return element
    }

    var enabledChildren: [AXUIElement]? {
        children?.filter(\.isEnabled)
    }

    var frame: CGRect? {
        guard
            let positionObject = copyAttribute(NSAccessibility.Attribute.position.rawValue),
            let sizeObject = copyAttribute(NSAccessibility.Attribute.size.rawValue)
        else {
            return nil
        }
        let positionValue = positionObject as! AXValue
        let sizeValue = sizeObject as! AXValue
        var position = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue, .cgPoint, &position),
            AXValueGetValue(sizeValue, .cgSize, &size)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private var role: String? {
        copyAttribute(kAXRoleAttribute) as? String
    }

    private var isEnabled: Bool {
        copyAttribute(kAXEnabledAttribute) as? Bool == true
    }

    private var children: [AXUIElement]? {
        copyAttribute(kAXChildrenAttribute) as? [AXUIElement]
    }

    private func copyAttribute(_ attribute: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }
}

// MARK: - Logger
private extension Logger {
    /// Logger to use for the menu bar manager.
    static let menuBarManager = Logger(category: "MenuBarManager")
}
