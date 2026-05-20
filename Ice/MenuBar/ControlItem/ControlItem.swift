//
//  ControlItem.swift
//  Ice
//

import Cocoa
import Combine

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
            appState.settingsManager.generalSettingsManager.$showIceIcon
                .receive(on: DispatchQueue.main)
                .sink { [weak self] showIceIcon in
                    guard
                        let self,
                        !isSectionDivider
                    else {
                        return
                    }
                    if showIceIcon {
                        addToMenuBar()
                    } else {
                        removeFromMenuBar()
                    }
                }
                .store(in: &c)

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
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
            if NSEvent.modifierFlags == .control {
                statusItem.showMenu(createMenu(with: appState))
            } else if
                NSEvent.modifierFlags == .option,
                canRevealAlwaysHiddenSection(with: appState)
            {
                if let alwaysHiddenSection = appState.menuBarManager.section(withName: .alwaysHidden) {
                    alwaysHiddenSection.toggle(rehideAfter: appState.settingsManager.advancedSettingsManager.tempShowInterval)
                }
            } else if
                section?.name == .alwaysHidden,
                !canRevealAlwaysHiddenSection(with: appState)
            {
                return
            } else {
                section?.toggle(rehideAfter: appState.settingsManager.advancedSettingsManager.tempShowInterval)
            }
        case .rightMouseUp:
            statusItem.showMenu(createMenu(with: appState))
        default:
            break
        }
    }

    /// Creates a menu to show under the control item.
    private func createMenu(with appState: AppState) -> NSMenu {
        let menu = NSMenu(title: "Ice")

        let settingsItem = NSMenuItem(
            title: "Ice Settings…",
            action: #selector(AppDelegate.openSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // Add menu items to toggle the hidden and always-hidden sections.
        let sectionNames: [MenuBarSection.Name] = if canRevealAlwaysHiddenSection(with: appState) {
            [.hidden, .alwaysHidden]
        } else {
            [.hidden]
        }
        for name in sectionNames {
            guard
                let section = appState.menuBarManager.section(withName: name),
                section.controlItem.isAddedToMenuBar
            else {
                // Section doesn't exist, or is disabled.
                continue
            }
            let item = NSMenuItem(
                title: "\(section.isHidden ? "Show" : "Hide") the \(name.displayString) Section",
                action: #selector(toggleMenuBarSection),
                keyEquivalent: ""
            )
            item.target = self
            Self.sectionStorage.weakSet(section, for: item)
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Ice",
            action: #selector(NSApp.terminate),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        return menu
    }

    /// Toggles the menu bar section associated with the given menu item.
    @objc private func toggleMenuBarSection(for menuItem: NSMenuItem) {
        guard let appState else {
            return
        }
        Self.sectionStorage.value(for: menuItem)?.toggle(rehideAfter: appState.settingsManager.advancedSettingsManager.tempShowInterval)
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

    /// A Boolean value that indicates whether the always-hidden section can be
    /// revealed by a user action.
    private func canRevealAlwaysHiddenSection(with appState: AppState) -> Bool {
        guard
            let alwaysHiddenSection = appState.menuBarManager.section(withName: .alwaysHidden),
            alwaysHiddenSection.isEnabled
        else {
            return false
        }

        let advancedManager = appState.settingsManager.advancedSettingsManager
        return advancedManager.enableAlwaysHiddenSection && advancedManager.canToggleAlwaysHiddenSection
    }
}

private extension ControlItem {
    /// Storage for menu items that toggle a menu bar section.
    ///
    /// When one of these menu items is created, its section is stored here.
    /// When its action is invoked, the section is retrieved from storage.
    static let sectionStorage = ObjectStorage<MenuBarSection>()
}

// MARK: - Logger
private extension Logger {
    /// The logger to use for control items.
    static let controlItem = Logger(category: "ControlItem")
}
