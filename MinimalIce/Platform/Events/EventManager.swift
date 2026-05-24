//
//  EventManager.swift
//  Ice
//

import Cocoa
import Combine

/// Manager for the various event monitors maintained by the app.
@MainActor
final class EventManager {
    /// The shared app state.
    private weak var appState: AppState?

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// Retries hiding click-revealed sections after menu bar item menus close.
    private var clickRevealRehideTimer: Timer?

    /// Retries hiding hover-revealed sections after menu bar item menus close.
    private var hoverRevealRehideTimer: Timer?

    private static let clickRevealRehideRetryInterval: TimeInterval = 0.25

    // MARK: Monitors

    /// Monitor for mouse down events.
    private(set) lazy var mouseDownMonitor = UniversalEventMonitor(
        mask: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] event in
        guard let self else {
            return event
        }
        switch event.type {
        case .leftMouseDown:
            handleShowOnClick()
        case .rightMouseDown:
            handleShowRightClickMenu()
        default:
            break
        }
        handlePreventShowOnHover(with: event)
        return event
    }

    /// Monitor for mouse dragged events.
    private(set) lazy var mouseDraggedMonitor = UniversalEventMonitor(
        mask: .leftMouseDragged
    ) { [weak self] event in
        self?.handleLeftMouseDragged(with: event)
        return event
    }

    /// Monitor for mouse moved events.
    private(set) lazy var mouseMovedMonitor = UniversalEventMonitor(
        mask: .mouseMoved
    ) { [weak self] event in
        self?.handleHideAfterClickReveal()
        self?.handleShowOnHover()
        return event
    }

    // MARK: All Monitors

    /// All monitors maintained by the app.
    private lazy var allMonitors = [
        mouseDownMonitor,
        mouseDraggedMonitor,
        mouseMovedMonitor,
    ]

    // MARK: Initializers

    /// Creates an event manager with the given app state.
    init(appState: AppState) {
        self.appState = appState
    }

    /// Sets up the manager.
    func performSetup() {
        startAll()
        configureCancellables()
    }

    /// Configures the internal observers for the manager.
    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        if
            let appState,
            let hiddenSection = appState.menuBarManager.section(withName: .hidden)
        {
            // In fullscreen mode, the menu bar slides down from the top on hover. Observe
            // the frame of the hidden section's control item, which we know will always be
            // in the menu bar, and run the show-on-hover check when it changes.
            Publishers.CombineLatest(
                hiddenSection.controlItem.$windowFrame,
                appState.$isActiveSpaceFullscreen
            )
            .sink { [weak self] _, isFullscreen in
                guard
                    let self,
                    isFullscreen
                else {
                    return
                }
                handleShowOnHover()
            }
            .store(in: &c)
        }

        cancellables = c
    }

    // MARK: Start/Stop

    /// Starts all monitors.
    func startAll() {
        for monitor in allMonitors {
            monitor.start()
        }
    }

    /// Stops all monitors.
    func stopAll() {
        for monitor in allMonitors {
            monitor.stop()
        }
    }
}

// MARK: - Handlers

extension EventManager {

    // MARK: Handle Show On Click

    private func handleShowOnClick() {
        guard
            let appState,
            appState.settingsManager.hiddenItemsActivationMode == .click,
            isMouseInsideEmptyMenuBarSpace
        else {
            return
        }

        Task { @MainActor [weak self, weak appState] in
            // Short delay helps the toggle action feel more natural.
            try? await Task.sleep(for: .milliseconds(50))

            guard
                let self,
                let appState
            else {
                return
            }

            let modifierFlags = NSEvent.modifierFlags

            if modifierFlags.contains(.control) {
                handleShowRightClickMenu()
            } else {
                appState.toggleMenuBarSection(using: modifierFlags)
            }
        }
    }

    // MARK: Handle Show Right Click Menu

    private func handleShowRightClickMenu() {
        guard
            let appState,
            isMouseInsideEmptyMenuBarSpace,
            let mouseLocation = MouseCursor.locationAppKit
        else {
            return
        }
        appState.menuBarManager.showRightClickMenu(at: mouseLocation)
    }

    // MARK: Handle Prevent Show On Hover

    private func handlePreventShowOnHover(with event: NSEvent) {
        guard
            let appState,
            appState.settingsManager.hiddenItemsActivationMode == .hover,
            isMouseInsideMenuBar
        else {
            return
        }

        guard shouldPreventShowOnHover(for: event, appState: appState) else {
            return
        }
        appState.preventShowOnHover()
    }

    private func shouldPreventShowOnHover(for event: NSEvent, appState: AppState) -> Bool {
        if !isMouseInsideMenuBarItem {
            return !isMouseInsideApplicationMenu
        }

        let hasShownSection = appState.menuBarManager.sections.contains { !$0.isHidden }
        switch event.type {
        case .leftMouseDown:
            return hasShownSection || isMouseInsideIceIcon
        case .rightMouseDown:
            return hasShownSection
        default:
            return false
        }
    }

    // MARK: Handle Left Mouse Dragged

    private func handleLeftMouseDragged(with event: NSEvent) {
        guard
            let appState,
            event.modifierFlags.contains(.command),
            isMouseInsideMenuBar
        else {
            return
        }

        // Show revealable items, including section dividers.
        for section in appState.menuBarManager.sections {
            guard appState.canShowSectionDuringCommandDrag(section) else {
                section.hide()
                continue
            }
            if section.controlItem.state != .showItems {
                section.controlItem.state = .showItems
            }
            guard
                section.name == .alwaysHidden,
                section.controlItem.isSectionDivider,
                !section.controlItem.isVisible
            else {
                continue
            }
            section.controlItem.isVisible = true
        }
    }

    // MARK: Handle Hide After Click Reveal

    private func handleHideAfterClickReveal() {
        guard
            let appState,
            appState.settingsManager.hiddenItemsActivationMode == .click
        else {
            cancelClickRevealRehide()
            return
        }

        guard hasClickRevealedSection(in: appState) else {
            cancelClickRevealRehide()
            return
        }

        guard !isMouseInsideMenuBar else {
            cancelClickRevealRehide()
            return
        }

        scheduleClickRevealRehide(after: appState.settingsManager.tempShowInterval)
    }

    private func hasClickRevealedSection(in appState: AppState) -> Bool {
        appState.menuBarManager.section(withName: .hidden)?.isHidden == false ||
        appState.menuBarManager.section(withName: .alwaysHidden)?.isHidden == false
    }

    private func attemptClickRevealRehide() {
        cancelClickRevealRehide()

        guard
            let appState,
            appState.settingsManager.hiddenItemsActivationMode == .click,
            hasClickRevealedSection(in: appState),
            !isMouseInsideMenuBar
        else {
            return
        }

        guard !isMenuBarItemInterfaceShown, !appState.itemManager.isMouseButtonDown else {
            scheduleClickRevealRehide(after: Self.clickRevealRehideRetryInterval)
            return
        }

        appState.menuBarManager.section(withName: .hidden)?.hide()
        appState.menuBarManager.section(withName: .alwaysHidden)?.hide()
    }

    private func scheduleClickRevealRehide(after delay: TimeInterval) {
        guard clickRevealRehideTimer == nil else {
            return
        }

        guard delay > 0 else {
            attemptClickRevealRehide()
            return
        }

        clickRevealRehideTimer = .scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.attemptClickRevealRehide()
            }
        }
    }

    private func cancelClickRevealRehide() {
        clickRevealRehideTimer?.invalidate()
        clickRevealRehideTimer = nil
    }

    private func cancelHoverRevealRehide() {
        hoverRevealRehideTimer?.invalidate()
        hoverRevealRehideTimer = nil
    }

    private func scheduleHoverRevealRehide() {
        guard hoverRevealRehideTimer == nil else {
            return
        }

        hoverRevealRehideTimer = .scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hoverRevealRehideTimer = nil
                self?.handleShowOnHover()
            }
        }
    }

    // MARK: Handle Show On Hover

    private func handleShowOnHover() {
        guard let appState else {
            return
        }

        if !isMouseInsideMenuBar {
            appState.allowShowOnHover()
        }

        // Make sure the "ShowOnHover" feature is enabled and not prevented.
        guard
            appState.settingsManager.hiddenItemsActivationMode == .hover,
            !appState.isShowOnHoverPrevented
        else {
            return
        }

        // Only continue if we have a hidden section (we should).
        guard let hiddenSection = appState.menuBarManager.section(withName: .hidden) else {
            return
        }

        Task { @MainActor in
            if hiddenSection.isHidden {
                guard self.isMouseInsideHoverActivationRegion else {
                    return
                }
                self.cancelHoverRevealRehide()
                hiddenSection.show()
            } else {
                guard !self.isMouseInsideMenuBar else {
                    self.cancelHoverRevealRehide()
                    return
                }
                guard !self.isMenuBarItemInterfaceShown else {
                    self.scheduleHoverRevealRehide()
                    return
                }
                self.cancelHoverRevealRehide()
                hiddenSection.hide()
            }
        }
    }

}

// MARK: - Helpers

extension EventManager {
    /// Returns the best screen to use for event manager calculations.
    var bestScreen: NSScreen? {
        guard let appState else {
            return nil
        }
        if appState.isActiveSpaceFullscreen {
            return NSScreen.screenWithMouse ?? NSScreen.main
        } else {
            return NSScreen.main
        }
    }

    /// A Boolean value that indicates whether the mouse pointer is within
    /// the bounds of the menu bar.
    var isMouseInsideMenuBar: Bool {
        guard
            let screen = bestScreen,
            let appState
        else {
            return false
        }
        if appState.menuBarManager.isMenuBarHiddenBySystem || appState.isActiveSpaceFullscreen {
            if
                let mouseLocation = MouseCursor.locationCoreGraphics,
                let menuBarWindow = WindowInfo.getMenuBarWindow(for: screen.displayID)
            {
                return menuBarWindow.frame.contains(mouseLocation)
            }
        } else if let mouseLocation = MouseCursor.locationAppKit {
            return mouseLocation.y > screen.visibleFrame.maxY && mouseLocation.y <= screen.frame.maxY
        }
        return false
    }

    /// A Boolean value that indicates whether a menu or popover opened from a
    /// menu bar item is still visible.
    var isMenuBarItemInterfaceShown: Bool {
        WindowInfo.getOnScreenWindows(excludeDesktopWindows: true).contains { window in
            window.isOnScreen && (
                window.layer == CGWindowLevelForKey(.popUpMenuWindow) ||
                window.layer == CGWindowLevelForKey(.popUpMenuWindow) + 1
            )
        }
    }

    /// A Boolean value that indicates whether the mouse pointer is within
    /// the bounds of the current application menu.
    var isMouseInsideApplicationMenu: Bool {
        guard
            let mouseLocation = MouseCursor.locationCoreGraphics,
            let screen = bestScreen,
            let appState,
            var applicationMenuFrame = appState.menuBarManager.getApplicationMenuFrame(for: screen.displayID)
        else {
            return false
        }
        applicationMenuFrame.size.width += applicationMenuFrame.origin.x - screen.frame.origin.x
        applicationMenuFrame.origin.x = screen.frame.origin.x
        return applicationMenuFrame.contains(mouseLocation)
    }

    /// A Boolean value that indicates whether the mouse pointer is within
    /// the bounds of a menu bar item.
    var isMouseInsideMenuBarItem: Bool {
        guard
            let screen = bestScreen,
            let mouseLocation = MouseCursor.locationCoreGraphics
        else {
            return false
        }
        let menuBarItems = MenuBarItem.getMenuBarItems(on: screen.displayID, onScreenOnly: true, activeSpaceOnly: true)
        return menuBarItems.contains { $0.frame.contains(mouseLocation) }
    }

    /// A Boolean value that indicates whether the mouse pointer is within
    /// the bounds of the screen's notch, if it has one.
    ///
    /// If the screen returned from ``bestScreen`` does not have a notch,
    /// this property returns `false`.
    var isMouseInsideNotch: Bool {
        guard
            let screen = bestScreen,
            let mouseLocation = MouseCursor.locationAppKit,
            let frameOfNotch = screen.frameOfNotch
        else {
            return false
        }
        return frameOfNotch.contains(mouseLocation)
    }

    /// A Boolean value that indicates whether the mouse pointer is within
    /// the bounds of an empty space in the menu bar.
    var isMouseInsideEmptyMenuBarSpace: Bool {
        isMouseInsideMenuBar &&
        !isMouseInsideApplicationMenu &&
        !isMouseInsideMenuBarItem &&
        !isMouseInsideNotch
    }

    /// A Boolean value that indicates whether the mouse pointer is in a region
    /// that should activate the "Show on hover" behavior.
    var isMouseInsideHoverActivationRegion: Bool {
        isMouseInsideIceIcon
    }

    /// A Boolean value that indicates whether the mouse pointer is within
    /// the bounds of the Ice icon.
    var isMouseInsideIceIcon: Bool {
        guard
            let appState,
            let visibleSection = appState.menuBarManager.section(withName: .visible),
            let iceIconFrame = visibleSection.controlItem.windowFrame,
            let mouseLocation = MouseCursor.locationAppKit
        else {
            return false
        }
        return iceIconFrame.contains(mouseLocation)
    }
}

// MARK: - Logger
private extension Logger {
    static let eventManager = Logger(category: "EventManager")
}
