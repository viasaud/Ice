//
//  WindowServerAdapter.swift
//  Ice
//

import CoreGraphics

/// Adapter for private WindowServer and connection behavior.
enum WindowServerAdapter {
    static var activeSpaceID: CGSSpaceID {
        Bridging.activeSpaceID
    }

    static func isSpaceFullscreen(_ spaceID: CGSSpaceID) -> Bool {
        Bridging.isSpaceFullscreen(spaceID)
    }

    static func windowFrame(for windowID: CGWindowID) -> CGRect? {
        Bridging.getWindowFrame(for: windowID)
    }

    static func windowList(option: Bridging.WindowListOption = []) -> [CGWindowID] {
        Bridging.getWindowList(option: option)
    }

    static func connectionProperty(forKey key: String) -> Any? {
        Bridging.getConnectionProperty(forKey: key)
    }

    static func setConnectionProperty(_ value: Any?, forKey key: String) {
        Bridging.setConnectionProperty(value, forKey: key)
    }
}
