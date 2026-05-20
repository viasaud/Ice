//
//  MenuBarManager.swift
//  Ice
//

@preconcurrency import AXSwift
import Combine
import SwiftUI

/// Manager for the state of the menu bar.
@MainActor
final class MenuBarManager: ObservableObject {
    /// Information for the menu bar's average color.
    @Published private(set) var averageColorInfo: MenuBarAverageColorInfo?

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

    /// A Boolean value that indicates whether the manager can update its stored
    /// information for the menu bar's average color.
    private var canUpdateAverageColorInfo: Bool {
        appState?.settingsWindow?.isVisible == true
    }

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

        appState?.settingsWindow?.publisher(for: \.isVisible)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAverageColorInfo()
            }
            .store(in: &c)

        Timer.publish(every: 5, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateAverageColorInfo()
            }
            .store(in: &c)

        cancellables = c
    }

    /// Updates the ``averageColorInfo`` property with a permission-free native
    /// fallback color.
    func updateAverageColorInfo() {
        guard canUpdateAverageColorInfo else {
            return
        }

        let info = MenuBarAverageColorInfo(color: NSColor.windowBackgroundColor.cgColor, source: .fallback)

        if averageColorInfo != info {
            averageColorInfo = info
        }
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
        let menu = NSMenu(title: "Ice")

        let settingsItem = NSMenuItem(
            title: "Ice Settings…",
            action: #selector(AppDelegate.openSettingsWindow),
            keyEquivalent: ","
        )
        menu.addItem(settingsItem)

        menu.popUp(positioning: nil, at: point, in: nil)
    }

    /// Returns the menu bar section with the given name.
    func section(withName name: MenuBarSection.Name) -> MenuBarSection? {
        sections.first { $0.name == name }
    }
}

// MARK: MenuBarManager: BindingExposable
extension MenuBarManager: BindingExposable { }

// MARK: - MenuBarAverageColorInfo

/// Information for the menu bar's average color.
struct MenuBarAverageColorInfo: Hashable {
    enum Source: Hashable {
        case menuBarWindow
        case desktopWallpaper
        case fallback
    }

    var color: CGColor
    var source: Source
}

// MARK: - Logger
private extension Logger {
    /// Logger to use for the menu bar manager.
    static let menuBarManager = Logger(category: "MenuBarManager")
}
