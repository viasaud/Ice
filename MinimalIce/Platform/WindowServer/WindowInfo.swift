//
//  WindowInfo.swift
//  Ice
//

import Cocoa

/// Information for a window.
struct WindowInfo {
    /// The window identifier associated with the window.
    let windowID: CGWindowID

    /// The frame of the window.
    ///
    /// The frame is specified in screen coordinates, where the origin
    /// is at the upper left corner of the main display.
    let frame: CGRect

    /// The title of the window.
    let title: String?

    /// The layer number of the window.
    let layer: Int

    /// The process identifier of the application that owns the window.
    let ownerPID: pid_t

    /// The name of the application that owns the window.
    ///
    /// This may have a value when ``owningApplication`` does not have a
    /// localized name.
    let ownerName: String?

    /// A Boolean value that indicates whether the window is on screen.
    let isOnScreen: Bool

    /// The application that owns the window.
    var owningApplication: NSRunningApplication? {
        NSRunningApplication(processIdentifier: ownerPID)
    }

    /// A Boolean value that indicates whether the window represents a
    /// menu bar item.
    var isMenuBarItem: Bool {
        layer == kCGStatusWindowLevel
    }

    /// A Boolean value that indicates whether the window belongs to the
    /// window server.
    var isWindowServerWindow: Bool {
        ownerName == "Window Server"
    }

    /// Creates a window with the given dictionary.
    private init?(dictionary: CFDictionary) {
        guard
            let info = dictionary as? [CFString: CFTypeRef],
            let windowID = info[kCGWindowNumber] as? CGWindowID,
            let boundsDict = info[kCGWindowBounds] as? NSDictionary,
            let frame = CGRect(dictionaryRepresentation: boundsDict),
            let layer = info[kCGWindowLayer] as? Int,
            let ownerPID = info[kCGWindowOwnerPID] as? pid_t
        else {
            return nil
        }
        self.windowID = windowID
        self.frame = frame
        self.title = info[kCGWindowName] as? String
        self.layer = layer
        self.ownerPID = ownerPID
        self.ownerName = info[kCGWindowOwnerName] as? String
        self.isOnScreen = info[kCGWindowIsOnscreen] as? Bool ?? false
    }

    /// Creates a window with the given window identifier.
    init?(windowID: CGWindowID) {
        var pointer = UnsafeRawPointer(bitPattern: Int(windowID))
        guard
            let array = CFArrayCreate(kCFAllocatorDefault, &pointer, 1, nil),
            let list = CGWindowListCreateDescriptionFromArray(array) as? [CFDictionary],
            let dictionary = list.first
        else {
            return nil
        }
        self.init(dictionary: dictionary)
    }

    /// Creates windows with the given window identifiers.
    static func windows(withIDs windowIDs: [CGWindowID]) -> [WindowInfo] {
        guard !windowIDs.isEmpty else {
            return []
        }

        var pointers = windowIDs.map { UnsafeRawPointer(bitPattern: Int($0)) }
        guard
            let array = pointers.withUnsafeMutableBufferPointer({
                CFArrayCreate(kCFAllocatorDefault, $0.baseAddress, $0.count, nil)
            }),
            let list = CGWindowListCreateDescriptionFromArray(array) as? [CFDictionary]
        else {
            return []
        }
        return list.compactMap { WindowInfo(dictionary: $0) }
    }
}

// MARK: - WindowList Operations
extension WindowInfo {
    private static func getWindowList(option: CGWindowListOption) -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo(option, kCGNullWindowID) as? [CFDictionary] else {
            return []
        }
        return list.compactMap { WindowInfo(dictionary: $0) }
    }
}

// MARK: On Screen Windows
extension WindowInfo {
    /// Returns the on screen windows.
    ///
    /// - Parameter excludeDesktopWindows: A Boolean value that indicates whether
    ///   to exclude desktop owned windows, such as the wallpaper and desktop icons.
    static func getOnScreenWindows(excludeDesktopWindows: Bool = false) -> [WindowInfo] {
        var option = CGWindowListOption.optionOnScreenOnly
        if excludeDesktopWindows {
            option.insert(.excludeDesktopElements)
        }
        return getWindowList(option: option)
    }
}

// MARK: Menu Bar Window
extension WindowInfo {
    /// Returns the menu bar window for the given display.
    static func getMenuBarWindow(from windows: [WindowInfo], for display: CGDirectDisplayID) -> WindowInfo? {
        let displayBounds = CGDisplayBounds(display)
        return windows.first { window in
            window.isWindowServerWindow &&
            window.isOnScreen &&
            window.layer == kCGMainMenuWindowLevel &&
            window.title == "Menubar" &&
            displayBounds.contains(window.frame)
        }
    }

    /// Returns the menu bar window for the given display.
    static func getMenuBarWindow(for display: CGDirectDisplayID) -> WindowInfo? {
        getMenuBarWindow(from: getOnScreenWindows(excludeDesktopWindows: true), for: display)
    }
}
