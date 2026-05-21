//
//  Predicates.swift
//  Ice
//

import Cocoa

enum Predicates<Input> {
    typealias NonThrowingPredicate = (Input) -> Bool
}

extension Predicates where Input == WindowInfo {
    static func wallpaperWindow(for display: CGDirectDisplayID) -> NonThrowingPredicate {
        { window in
            // wallpaper window belongs to the Dock process
            window.owningApplication?.bundleIdentifier == "com.apple.dock" &&
            window.title?.hasPrefix("Wallpaper") == true &&
            CGDisplayBounds(display).contains(window.frame)
        }
    }

    static func menuBarWindow(for display: CGDirectDisplayID) -> NonThrowingPredicate {
        { window in
            // menu bar window belongs to the WindowServer process
            window.isWindowServerWindow &&
            window.isOnScreen &&
            window.layer == kCGMainMenuWindowLevel &&
            window.title == "Menubar" &&
            CGDisplayBounds(display).contains(window.frame)
        }
    }
}

extension Predicates where Input == NSLayoutConstraint {
    @MainActor
    static func controlItemConstraint(button: NSStatusBarButton) -> NonThrowingPredicate {
        let buttonSuperview = button.superview
        return { constraint in
            constraint.secondItem === buttonSuperview
        }
    }
}
