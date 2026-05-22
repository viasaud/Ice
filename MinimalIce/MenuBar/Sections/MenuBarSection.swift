//
//  MenuBarSection.swift
//  Ice
//

import Cocoa

/// A representation of a section in a menu bar.
@MainActor
final class MenuBarSection {
    /// The name of a menu bar section.
    enum Name: CaseIterable {
        case visible
        case hidden
        case alwaysHidden

        /// A string to show in the interface.
        var displayString: String {
            switch self {
            case .visible: "Visible"
            case .hidden: "Hidden"
            case .alwaysHidden: "Always-Hidden"
            }
        }

        /// A string to use for logging purposes.
        var logString: String {
            switch self {
            case .visible: "visible section"
            case .hidden: "hidden section"
            case .alwaysHidden: "always-hidden section"
            }
        }
    }

    /// The name of the section.
    let name: Name

    /// The control item that manages the section.
    let controlItem: ControlItem

    /// The shared app state.
    private weak var appState: AppState?

    /// A timer that manages rehiding the section.
    private var rehideTimer: Timer?

    /// A Boolean value that indicates whether the section is hidden.
    var isHidden: Bool {
        controlItem.state == .hideItems
    }

    /// A Boolean value that indicates whether the section is enabled.
    var isEnabled: Bool {
        name == .visible || controlItem.isAddedToMenuBar
    }

    /// Creates a section with the given name, control item, and app state.
    init(name: Name, controlItem: ControlItem, appState: AppState) {
        self.name = name
        self.controlItem = controlItem
        self.appState = appState
    }

    /// Creates a section with the given name and app state.
    convenience init(name: Name, appState: AppState) {
        let controlItem = switch name {
        case .visible:
            ControlItem(identifier: .iceIcon, appState: appState)
        case .hidden:
            ControlItem(identifier: .hidden, appState: appState)
        case .alwaysHidden:
            ControlItem(identifier: .alwaysHidden, appState: appState)
        }
        self.init(name: name, controlItem: controlItem, appState: appState)
    }

    /// Shows the section.
    func show(rehideAfter delay: TimeInterval? = nil) {
        guard
            let appState,
            isHidden
        else {
            return
        }
        guard
            isEnabled,
            let sectionsToShow = sectionsToShow(in: appState)
        else {
            return
        }

        sectionsToShow.forEach { $0.setControlItemState(.showItems) }
        startRehideTimer(after: delay)
    }

    private func sectionsToShow(in appState: AppState) -> [MenuBarSection]? {
        switch name {
        case .visible:
            guard let hiddenSection = appState.menuBarManager.section(withName: .hidden) else {
                return nil
            }
            return [self, hiddenSection]
        case .hidden:
            guard let visibleSection = appState.menuBarManager.section(withName: .visible) else {
                return nil
            }
            return [self, visibleSection]
        case .alwaysHidden:
            guard
                let hiddenSection = appState.menuBarManager.section(withName: .hidden),
                let visibleSection = appState.menuBarManager.section(withName: .visible)
            else {
                return nil
            }
            return [self, hiddenSection, visibleSection]
        }
    }

    /// Hides the section.
    func hide() {
        guard
            let appState,
            !isHidden
        else {
            return
        }

        guard let sectionsToHide = sectionsToHide(in: appState) else {
            return
        }

        sectionsToHide.forEach { $0.setControlItemState(.hideItems) }
        appState.allowShowOnHover()
        stopRehideChecks()
    }

    private func sectionsToHide(in appState: AppState) -> [MenuBarSection]? {
        switch name {
        case .visible:
            guard
                let hiddenSection = appState.menuBarManager.section(withName: .hidden),
                let alwaysHiddenSection = appState.menuBarManager.section(withName: .alwaysHidden)
            else {
                return nil
            }
            return [self, hiddenSection, alwaysHiddenSection]
        case .hidden:
            guard
                let visibleSection = appState.menuBarManager.section(withName: .visible),
                let alwaysHiddenSection = appState.menuBarManager.section(withName: .alwaysHidden)
            else {
                return nil
            }
            return [self, visibleSection, alwaysHiddenSection]
        case .alwaysHidden:
            return [self]
        }
    }

    /// Toggles the visibility of the section.
    func toggle(rehideAfter delay: TimeInterval? = nil) {
        if isHidden {
            show(rehideAfter: delay)
        } else {
            hide()
        }
    }

    /// Starts a timer to rehide the section.
    private func startRehideTimer(after delay: TimeInterval?) {
        rehideTimer?.invalidate()

        guard let delay else {
            return
        }

        rehideTimer = .scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hide()
            }
        }
    }

    /// Stops running checks to determine when to rehide the section.
    private func stopRehideChecks() {
        rehideTimer?.invalidate()
        rehideTimer = nil
    }

    private func setControlItemState(_ state: ControlItem.HidingState) {
        guard controlItem.state != state else {
            return
        }
        controlItem.state = state
    }
}
