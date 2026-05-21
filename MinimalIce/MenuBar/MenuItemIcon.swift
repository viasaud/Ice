//
//  MenuItemIcon.swift
//  Ice
//

import Cocoa

/// Native template icons used in Minimal Ice menus.
enum MenuItemIcon {
    static let reveal = symbol("eye")
    static let click = symbol("cursorarrow.click")
    static let hover = symbol("hand.point.up.left")
    static let dividers = symbol("rectangle.split.3x1")
    static let alwaysHidden = symbol("eye.slash")
    static let hideAfter = symbol("timer")
    static let interval = symbol("clock")
    static let launchAtStartup = symbol("play.circle")
    static let version = symbol("info.circle")
    static let quit = symbol("power")

    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }
}
