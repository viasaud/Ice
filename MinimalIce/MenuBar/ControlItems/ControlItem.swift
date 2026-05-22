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
    enum HidingState: Equatable {
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
        Self.setDefaultPositionIfNeeded(for: identifier, autosaveName: autosaveName)

        let statusItem = NSStatusBar.system.statusItem(withLength: 0)
        statusItem.autosaveName = autosaveName
        self.statusItem = statusItem
        self.identifier = identifier
        self.appState = appState
        self.constraint = Self.zeroLengthConstraint(for: statusItem.button)

        configureStatusItem()
    }

    private static func setDefaultPositionIfNeeded(for identifier: Identifier, autosaveName: String) {
        guard Defaults.statusItemPreferredPosition(for: autosaveName) == nil else {
            return
        }

        switch identifier {
        case .iceIcon:
            Defaults.setStatusItemPreferredPosition(0, for: autosaveName)
        case .hidden:
            Defaults.setStatusItemPreferredPosition(1, for: autosaveName)
        case .alwaysHidden:
            break
        }
    }

    private static func zeroLengthConstraint(for button: NSStatusBarButton?) -> NSLayoutConstraint? {
        // Keep this AppKit workaround isolated: section dividers need zero length
        // while remaining in the menu bar as item delimiters.
        if
            let button,
            let constraints = button.window?.contentView?.constraintsAffectingLayout(for: .horizontal),
            let constraint = constraints.first(where: { $0.secondItem === button.superview })
        {
            assert(constraints.filter { $0.secondItem === button.superview }.count == 1)
            return constraint
        } else {
            return nil
        }
    }

    /// Removes the status item without clearing its stored position.
    deinit {
        MainActor.assumeIsolated {
            // Removing the status item has the unwanted side effect of deleting
            // the preferredPosition. Cache and restore it.
            let autosaveName = statusItem.autosaveName as String
            let cached = Defaults.statusItemPreferredPosition(for: autosaveName)
            NSStatusBar.system.removeStatusItem(statusItem)
            Defaults.setStatusItemPreferredPosition(cached, for: autosaveName)
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
                self?.setVisible(isActive)
            }
            .store(in: &c)

        window?.publisher(for: \.frame)
            .removeDuplicates()
            .sink { [weak self] frame in
                guard
                    let self,
                    let screen = window?.screen,
                    screen.frame.intersects(frame)
                else {
                    return
                }
                setWindowFrame(frame)
            }
            .store(in: &c)

        if let appState {
            appState.settingsManager.$showSectionDividers
                .receive(on: DispatchQueue.main)
                .sink { [weak self] shouldShow in
                    guard
                        let self,
                        isSectionDivider,
                        state == .showItems
                    else {
                        return
                    }
                    setVisible(shouldShow && section?.name == .alwaysHidden)
                }
                .store(in: &c)

            appState.settingsManager.$enableAlwaysHiddenSection
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

    private func setVisible(_ isVisible: Bool) {
        guard self.isVisible != isVisible else {
            return
        }
        self.isVisible = isVisible
    }

    private func setWindowFrame(_ frame: CGRect) {
        guard windowFrame != frame else {
            return
        }
        windowFrame = frame
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
            setVisible(true)
            // Enable the cell, as it may have been previously disabled.
            button.cell?.isEnabled = true
            button.image = switch state {
            case .hideItems: ControlItemImages.chevronLarge
            case .showItems: ControlItemImages.chevronLarge
            }
        case .hidden, .alwaysHidden:
            switch state {
            case .hideItems:
                setVisible(true)
                // Prevent the cell from highlighting while expanded.
                button.cell?.isEnabled = false
                // Cell still sometimes briefly flashes on expansion unless manually unhighlighted.
                button.isHighlighted = false
                button.image = nil
            case .showItems:
                setVisible(shouldShowSectionDivider(appState: appState))
                // Enable the cell, as it may have been previously disabled.
                button.cell?.isEnabled = true
                // Set the image based on the section name and the hiding state.
                switch section.name {
                case .hidden:
                    button.image = nil
                case .alwaysHidden:
                    button.image = ControlItemImages.chevronLarge
                case .visible: break
                }
            }
        }
    }

    private func shouldShowSectionDivider(appState: AppState) -> Bool {
        guard appState.settingsManager.showSectionDividers else {
            return false
        }
        return section?.name == .alwaysHidden
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
                statusItem.showMenu(appState.menuBarManager.createMenu())
            } else {
                appState.toggleMenuBarSection(using: modifierFlags, preferredSection: section)
            }
        case .rightMouseUp:
            statusItem.showMenu(appState.menuBarManager.createMenu())
        default:
            break
        }
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
        let cached = Defaults.statusItemPreferredPosition(for: autosaveName)
        statusItem.isVisible = false
        Defaults.setStatusItemPreferredPosition(cached, for: autosaveName)
    }
}

private enum ControlItemImages {
    static let chevronLarge = chevron(size: CGSize(width: 12, height: 12), lineWidth: 2)

    private static func chevron(size: CGSize, lineWidth: CGFloat) -> NSImage {
        let image = NSImage(size: size, flipped: false) { bounds in
            let insetBounds = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let path = NSBezierPath()
            path.move(to: CGPoint(x: (insetBounds.midX + insetBounds.maxX) / 2, y: insetBounds.maxY))
            path.line(to: CGPoint(x: (insetBounds.minX + insetBounds.midX) / 2, y: insetBounds.midY))
            path.line(to: CGPoint(x: (insetBounds.midX + insetBounds.maxX) / 2, y: insetBounds.minY))
            path.lineWidth = lineWidth
            path.lineCapStyle = .butt
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
