//
//  ControlItem.swift
//  Ice
//

import Cocoa
import Combine
import LaunchAtLogin

/// A status item that controls a section in the menu bar.
@MainActor
final class ControlItem {
    /// Possible identifiers for control items.
    enum Identifier: String, CaseIterable {
        case iceIcon = "SItem"
        case hidden = "HItem"
        case alwaysHidden = "AHItem"
    }

    /// Possible hiding states for control items.
    enum HidingState {
        case hideItems, showItems
    }

    /// Possible lengths for control items.
    enum Lengths {
        static let standard: CGFloat = NSStatusItem.variableLength
        static let expanded: CGFloat = 10_000
    }

    /// The control item's hiding state (`@Published`).
    @Published var state = HidingState.hideItems

    /// A Boolean value that indicates whether the control item is visible (`@Published`).
    @Published var isVisible = true

    /// The frame of the control item's window (`@Published`).
    @Published private(set) var windowFrame: CGRect?

    /// The shared app state.
    private weak var appState: AppState?

    /// The control item's underlying status item.
    private let statusItem: NSStatusItem

    /// A horizontal constraint for the control item's content view.
    private let constraint: NSLayoutConstraint?

    /// The control item's identifier.
    private let identifier: Identifier

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// The menu bar section associated with the control item.
    private weak var section: MenuBarSection? {
        appState?.menuBarManager.sections.first { $0.controlItem === self }
    }

    /// The control item's window.
    var window: NSWindow? {
        statusItem.button?.window
    }

    /// The identifier of the control item's window.
    var windowID: CGWindowID? {
        guard let window else {
            return nil
        }
        return CGWindowID(exactly: window.windowNumber)
    }

    /// A Boolean value that indicates whether the control item serves as
    /// a divider between sections.
    var isSectionDivider: Bool {
        identifier != .iceIcon
    }

    /// A Boolean value that indicates whether the control item is currently
    /// displayed in the menu bar.
    var isAddedToMenuBar: Bool {
        statusItem.isVisible
    }

    /// Creates a control item with the given identifier and app state.
    init(identifier: Identifier, appState: AppState) {
        let autosaveName = identifier.rawValue

        // If the status item doesn't have a preferred position, set it
        // according to the identifier.
        if StatusItemDefaults[.preferredPosition, autosaveName] == nil {
            switch identifier {
            case .iceIcon:
                StatusItemDefaults[.preferredPosition, autosaveName] = 0
            case .hidden:
                StatusItemDefaults[.preferredPosition, autosaveName] = 1
            case .alwaysHidden:
                break
            }
        }

        self.statusItem = NSStatusBar.system.statusItem(withLength: 0)
        self.statusItem.autosaveName = autosaveName
        self.identifier = identifier
        self.appState = appState

        // This could break in a new macOS release, but we need this constraint in order to be
        // able to hide the control item when the `ShowSectionDividers` setting is disabled. A
        // previous implementation used the status item's `isVisible` property, which was more
        // robust, but would completely remove the control item. With the current set of
        // features, we need to be able to accurately retrieve the items for each section, so
        // we need the control item to always be present to act as a delimiter. The new solution
        // is to remove the constraint that prevents status items from having a length of zero,
        // then resize the content view. FIXME: Find a replacement for this.
        if
            let button = statusItem.button,
            let constraints = button.window?.contentView?.constraintsAffectingLayout(for: .horizontal),
            let constraint = constraints.first(where: Predicates.controlItemConstraint(button: button))
        {
            assert(constraints.filter(Predicates.controlItemConstraint(button: button)).count == 1)
            self.constraint = constraint
        } else {
            self.constraint = nil
        }

        configureStatusItem()
    }

    /// Removes the status item without clearing its stored position.
    deinit {
        MainActor.assumeIsolated {
            // Removing the status item has the unwanted side effect of deleting
            // the preferredPosition. Cache and restore it.
            let autosaveName = statusItem.autosaveName as String
            let cached = StatusItemDefaults[.preferredPosition, autosaveName]
            NSStatusBar.system.removeStatusItem(statusItem)
            StatusItemDefaults[.preferredPosition, autosaveName] = cached
        }
    }

    /// Configures the internal observers for the control item.
    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        $state
            .sink { [weak self] state in
                self?.updateStatusItem(with: state)
            }
            .store(in: &c)

        Publishers.CombineLatest($isVisible, $state)
            .sink { [weak self] (isVisible, state) in
                self?.updateStatusItemLength(isVisible: isVisible, state: state)
            }
            .store(in: &c)

        constraint?.publisher(for: \.isActive)
            .removeDuplicates()
            .sink { [weak self] isActive in
                self?.isVisible = isActive
            }
            .store(in: &c)

        window?.publisher(for: \.frame)
            .sink { [weak self] frame in
                guard
                    let self,
                    let screen = window?.screen,
                    screen.frame.intersects(frame)
                else {
                    return
                }
                windowFrame = frame
            }
            .store(in: &c)

        if let appState {
            appState.settingsManager.advancedSettingsManager.$showSectionDividers
                .receive(on: DispatchQueue.main)
                .sink { [weak self] shouldShow in
                    guard
                        let self,
                        isSectionDivider,
                        state == .showItems
                    else {
                        return
                    }
                    isVisible = shouldShow
                }
                .store(in: &c)

            appState.settingsManager.advancedSettingsManager.$enableAlwaysHiddenSection
                .receive(on: DispatchQueue.main)
                .sink { [weak self] enable in
                    guard
                        let self,
                        identifier == .alwaysHidden
                    else {
                        return
                    }
                    if enable {
                        addToMenuBar()
                    } else {
                        removeFromMenuBar()
                    }
                }
                .store(in: &c)
        }

        cancellables = c
    }

    /// Sets the initial configuration for the status item.
    private func configureStatusItem() {
        defer {
            configureCancellables()
            updateStatusItem(with: state)
        }
        guard let button = statusItem.button else {
            return
        }
        button.target = self
        button.action = #selector(performAction)
        button.sendAction(on: [.leftMouseDown, .rightMouseUp])
    }

    /// Updates the appearance of the status item using the given hiding state.
    private func updateStatusItem(with state: HidingState) {
        guard
            let appState,
            let section,
            let button = statusItem.button
        else {
            return
        }

        switch section.name {
        case .visible:
            isVisible = true
            // Enable the cell, as it may have been previously disabled.
            button.cell?.isEnabled = true
            button.image = switch state {
            case .hideItems: ControlItemImage.builtin(.chevronLarge).nsImage(for: appState)
            case .showItems: ControlItemImage.builtin(.chevronLarge).nsImage(for: appState)
            }
        case .hidden, .alwaysHidden:
            switch state {
            case .hideItems:
                isVisible = true
                // Prevent the cell from highlighting while expanded.
                button.cell?.isEnabled = false
                // Cell still sometimes briefly flashes on expansion unless manually unhighlighted.
                button.isHighlighted = false
                button.image = nil
            case .showItems:
                isVisible = appState.settingsManager.advancedSettingsManager.showSectionDividers
                // Enable the cell, as it may have been previously disabled.
                button.cell?.isEnabled = true
                // Set the image based on the section name and the hiding state.
                switch section.name {
                case .hidden:
                    button.image = ControlItemImage.builtin(.chevronLarge).nsImage(for: appState)
                case .alwaysHidden:
                    button.image = ControlItemImage.builtin(.chevronSmall).nsImage(for: appState)
                case .visible: break
                }
            }
        }
    }

    /// Updates the status item's menu bar footprint using the current section state.
    private func updateStatusItemLength(isVisible: Bool, state: HidingState) {
        guard let section else {
            return
        }
        if isVisible {
            statusItem.length = switch section.name {
            case .visible: Lengths.standard
            case .hidden, .alwaysHidden:
                switch state {
                case .hideItems: Lengths.expanded
                case .showItems: Lengths.standard
                }
            }
            constraint?.isActive = true
        } else {
            statusItem.length = 0
            constraint?.isActive = false
            if let window {
                var size = window.frame.size
                size.width = 1
                window.setContentSize(size)
            }
        }
    }

    /// Re-applies the current state after the manager has finished creating sections.
    func refreshStatusItem() {
        updateStatusItem(with: state)
        updateStatusItemLength(isVisible: isVisible, state: state)
    }

    /// Performs the control item's action.
    @objc private func performAction() {
        guard
            let appState,
            let event = NSApp.currentEvent
        else {
            return
        }
        switch event.type {
        case .leftMouseDown, .leftMouseUp:
            let modifierFlags = event.modifierFlags

            if modifierFlags.contains(.control) {
                statusItem.showMenu(createMenu())
            } else {
                appState.toggleMenuBarSection(using: modifierFlags, preferredSection: section)
            }
        case .rightMouseUp:
            statusItem.showMenu(createMenu())
        default:
            break
        }
    }

    /// Creates a menu to show under the control item.
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

    /// Adds the control item to the menu bar.
    func addToMenuBar() {
        guard !isAddedToMenuBar else {
            return
        }
        statusItem.isVisible = true
    }

    /// Removes the control item from the menu bar.
    func removeFromMenuBar() {
        guard isAddedToMenuBar else {
            return
        }
        // Setting `statusItem.isVisible` to `false` has the unwanted side
        // effect of deleting the preferredPosition. Cache and restore it.
        let autosaveName = statusItem.autosaveName as String
        let cached = StatusItemDefaults[.preferredPosition, autosaveName]
        statusItem.isVisible = false
        StatusItemDefaults[.preferredPosition, autosaveName] = cached
    }

}

private extension ControlItem {
    static let rehideIntervals: [TimeInterval] = [0, 5, 10, 15, 20, 30]
}

// MARK: - Logger
private extension Logger {
    /// The logger to use for control items.
    static let controlItem = Logger(category: "ControlItem")
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
