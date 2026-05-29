//
//  MenuBarItem.swift
//  Ice
//

import Cocoa

struct MenuBarItemInfo: Hashable, CustomStringConvertible {
    let namespace: Namespace
    let title: String

    var description: String {
        namespace.rawValue + ":" + title
    }

    init(namespace: Namespace, title: String) {
        self.namespace = namespace
        self.title = title
    }
}

extension MenuBarItemInfo {
    static let immovableItems = [clock, siri, controlCenter]
    static let nonHideableItems = [audioVideoModule, faceTime, musicRecognition]

    static let iceIcon = Self(namespace: .ice, title: ControlItem.Identifier.iceIcon.rawValue)
    static let hiddenControlItem = Self(namespace: .ice, title: ControlItem.Identifier.hidden.rawValue)
    static let alwaysHiddenControlItem = Self(namespace: .ice, title: ControlItem.Identifier.alwaysHidden.rawValue)
    static let clock = Self(namespace: .controlCenter, title: "Clock")
    static let siri = Self(namespace: .systemUIServer, title: "Siri")
    static let controlCenter = Self(namespace: .controlCenter, title: "BentoBox")
    static let audioVideoModule = Self(namespace: .controlCenter, title: "AudioVideoModule")
    static let faceTime = Self(namespace: .controlCenter, title: "FaceTime")
    static let musicRecognition = Self(namespace: .controlCenter, title: "MusicRecognition")
}

extension MenuBarItemInfo {
    struct Namespace: Hashable, RawRepresentable, CustomStringConvertible {
        let rawValue: String

        var description: String {
            rawValue
        }

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        init(_ rawValue: String) {
            self.init(rawValue: rawValue)
        }

        init(_ value: String?) {
            self = value.map { Self($0) } ?? .null
        }
    }
}

extension MenuBarItemInfo.Namespace {
    static let ice = Self(Constants.bundleIdentifier)
    static let controlCenter = Self("com.apple.controlcenter")
    static let systemUIServer = Self("com.apple.systemuiserver")
    static let null = Self("<null>")
}

// MARK: - MenuBarItem

/// A representation of an item in the menu bar.
struct MenuBarItem {
    /// The item's window.
    let window: WindowInfo

    /// The menu bar item info associated with this item.
    let info: MenuBarItemInfo

    /// The identifier of the item's window.
    var windowID: CGWindowID {
        window.windowID
    }

    /// The frame of the item's window.
    var frame: CGRect {
        window.frame
    }

    /// The title of the item's window.
    var title: String? {
        window.title
    }

    /// A Boolean value that indicates whether the item is on screen.
    var isOnScreen: Bool {
        window.isOnScreen
    }

    /// A Boolean value that indicates whether the item can be moved.
    var isMovable: Bool {
        !Self.immovableItems.contains(info)
    }

    /// A Boolean value that indicates whether the item can be hidden.
    var canBeHidden: Bool {
        !Self.nonHideableItems.contains(info)
    }

    /// The process identifier of the application that owns the item.
    var ownerPID: pid_t {
        window.ownerPID
    }

    /// The name of the application that owns the item.
    ///
    /// This may have a value when ``owningApplication`` does not have
    /// a localized name.
    var ownerName: String? {
        window.ownerName
    }

    /// The application that owns the item.
    var owningApplication: NSRunningApplication? {
        window.owningApplication
    }

    /// A name associated with the item that is suited for display to
    /// the user.
    var displayName: String {
        guard let owningApplication else {
            return ownerName ?? title ?? Self.unknownDisplayName
        }
        guard let title else {
            return bestDisplayName(for: owningApplication)
        }
        return displayName(for: title, ownedBy: owningApplication)
    }

    /// A string to use for logging purposes.
    var logString: String {
        String(describing: info)
    }

    /// Creates a menu bar item from the given window.
    ///
    /// This initializer does not perform any checks on the window to ensure that
    /// it is a valid menu bar item window. Only call this initializer if you are
    /// certain that the window is valid.
    private init(uncheckedItemWindow itemWindow: WindowInfo) {
        self.window = itemWindow
        self.info = MenuBarItemInfo(uncheckedItemWindow: itemWindow)
    }

    /// Creates a menu bar item.
    ///
    /// The parameters passed into this initializer are verified during the menu
    /// bar item's creation. If `itemWindow` does not represent a menu bar item,
    /// the initializer will fail.
    ///
    /// - Parameter itemWindow: A window that contains information about the item.
    init?(itemWindow: WindowInfo) {
        guard itemWindow.isMenuBarItem else {
            return nil
        }
        self.init(uncheckedItemWindow: itemWindow)
    }

    /// Creates a menu bar item with the given window identifier.
    ///
    /// The parameters passed into this initializer are verified during the menu
    /// bar item's creation. If `windowID` does not represent a menu bar item,
    /// the initializer will fail.
    ///
    /// - Parameter windowID: An identifier for a window that contains information
    ///   about the item.
    init?(windowID: CGWindowID) {
        guard let window = WindowInfo(windowID: windowID) else {
            return nil
        }
        self.init(itemWindow: window)
    }
}

private extension MenuBarItem {
    static let unknownDisplayName = "Unknown"
    static let immovableItems = Set(MenuBarItemInfo.immovableItems)
    static let nonHideableItems = Set(MenuBarItemInfo.nonHideableItems)

    func bestDisplayName(for application: NSRunningApplication) -> String {
        application.localizedName ??
        ownerName ??
        application.bundleIdentifier ??
        Self.unknownDisplayName
    }

    func displayName(for title: String, ownedBy application: NSRunningApplication) -> String {
        let bestName = bestDisplayName(for: application)

        return switch MenuBarItemInfo.Namespace(application.bundleIdentifier) {
        case .controlCenter:
            controlCenterDisplayName(for: title, fallback: bestName)
        case .systemUIServer:
            systemUIServerDisplayName(for: title)
        case MenuBarItemInfo.Namespace("com.apple.Passwords.MenuBarExtra"):
            "Passwords"
        default:
            bestName
        }
    }

    func controlCenterDisplayName(for title: String, fallback: String) -> String {
        switch title {
        case "AccessibilityShortcuts": "Accessibility Shortcuts"
        case "BentoBox": fallback
        case "FocusModes": "Focus"
        case "KeyboardBrightness": "Keyboard Brightness"
        case "MusicRecognition": "Music Recognition"
        case "NowPlaying": "Now Playing"
        case "ScreenMirroring": "Screen Mirroring"
        case "StageManager": "Stage Manager"
        case "UserSwitcher": "Fast User Switching"
        case "WiFi": "Wi-Fi"
        default: title
        }
    }

    func systemUIServerDisplayName(for title: String) -> String {
        switch title {
        case "TimeMachine.TMMenuExtraHost", "TimeMachineMenuExtra.TMMenuExtraHost":
            "Time Machine"
        default:
            title
        }
    }
}

// MARK: MenuBarItem Getters
extension MenuBarItem {
    /// Returns an array of the current menu bar items in the menu bar on the given display.
    ///
    /// - Parameters:
    ///   - display: The display to retrieve the menu bar items on. Pass `nil` to return the
    ///     menu bar items across all displays.
    ///   - onScreenOnly: A Boolean value that indicates whether only the menu bar items that
    ///     are on screen should be returned.
    ///   - activeSpaceOnly: A Boolean value that indicates whether only the menu bar items
    ///     that are on the active space should be returned.
    static func getMenuBarItems(on display: CGDirectDisplayID? = nil, onScreenOnly: Bool, activeSpaceOnly: Bool) -> [MenuBarItem] {
        return WindowServerAdapter.menuBarItemWindows(
            on: display,
            onScreenOnly: onScreenOnly,
            activeSpaceOnly: activeSpaceOnly
        )
            .lazy
            .compactMap(MenuBarItem.init(itemWindow:))
            .filter { !activeSpaceOnly || $0.title != "" }
            .sortedByOrderInMenuBar()
    }
}

// MARK: MenuBarItemInfo Unchecked Item Window Initializer
private extension MenuBarItemInfo {
    /// Creates a simplified item from the given window.
    ///
    /// This initializer does not perform any checks on the window to ensure that
    /// it is a valid menu bar item window. Only call this initializer if you are
    /// certain that the window is valid.
    init(uncheckedItemWindow itemWindow: WindowInfo) {
        if let bundleIdentifier = itemWindow.owningApplication?.bundleIdentifier {
            self.namespace = Namespace(bundleIdentifier)
        } else {
            self.namespace = .null
        }
        if let title = itemWindow.title {
            self.title = title
        } else {
            self.title = ""
        }
    }
}
