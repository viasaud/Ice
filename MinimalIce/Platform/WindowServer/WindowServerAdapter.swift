//
//  WindowServerAdapter.swift
//  Ice
//

import CoreGraphics

/// Adapter for private WindowServer and connection behavior.
enum WindowServerAdapter {
    private static let cursorBackgroundConnectionKey = "SetsCursorInBackground"

    private static var activeSpaceID: CGSSpaceID {
        Bridging.activeSpaceID
    }

    static var isActiveSpaceFullscreen: Bool {
        Bridging.isSpaceFullscreen(activeSpaceID)
    }

    static var activeSpaceMenuBarItemWindowIDs: [CGWindowID] {
        Bridging.getWindowList(option: [.menuBarItems, .activeSpace])
    }

    static var canSetCursorInBackground: Bool {
        get { Bridging.getConnectionProperty(forKey: cursorBackgroundConnectionKey) as? Bool ?? false }
        set { Bridging.setConnectionProperty(newValue, forKey: cursorBackgroundConnectionKey) }
    }

    static func menuBarItemFrame(for windowID: CGWindowID) -> CGRect? {
        Bridging.getWindowFrame(for: windowID)
    }

    static func menuBarItemWindows(
        on display: CGDirectDisplayID? = nil,
        onScreenOnly: Bool,
        activeSpaceOnly: Bool
    ) -> [WindowInfo] {
        var option: Bridging.WindowListOption = [.menuBarItems]

        if onScreenOnly {
            option.insert(.onScreen)
        }
        if activeSpaceOnly {
            option.insert(.activeSpace)
        }

        let displayBounds = display.map(CGDisplayBounds)
        return WindowInfo.windows(withIDs: Bridging.getWindowList(option: option)).filter { window in
            displayBounds?.intersects(window.frame) ?? true
        }
    }
}
