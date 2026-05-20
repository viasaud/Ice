//
//  Extensions.swift
//  Ice
//

import Combine
import SwiftUI

// MARK: - CGError

extension CGError {
    /// A string to use for logging purposes.
    var logString: String {
        switch self {
        case .success: "\(rawValue): success"
        case .failure: "\(rawValue): failure"
        case .illegalArgument: "\(rawValue): illegalArgument"
        case .invalidConnection: "\(rawValue): invalidConnection"
        case .invalidContext: "\(rawValue): invalidContext"
        case .cannotComplete: "\(rawValue): cannotComplete"
        case .notImplemented: "\(rawValue): notImplemented"
        case .rangeCheck: "\(rawValue): rangeCheck"
        case .typeCheck: "\(rawValue): typeCheck"
        case .invalidOperation: "\(rawValue): invalidOperation"
        case .noneAvailable: "\(rawValue): noneAvailable"
        @unknown default: "\(rawValue): unknown"
        }
    }
}

// MARK: - Collection where Element == MenuBarItem

extension Collection where Element == MenuBarItem {
    /// Returns the first index where the menu bar item matching the specified
    /// info appears in the collection.
    func firstIndex(matching info: MenuBarItemInfo) -> Index? {
        firstIndex { $0.info == info }
    }
}

// MARK: - Comparable

extension Comparable {
    /// Returns a copy of this value that has been clamped within the bounds
    /// of the given limiting range.
    ///
    /// - Parameter limits: A closed range within which to clamp this value.
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

// MARK: - NSScreen

extension NSScreen {
    /// The screen containing the mouse pointer.
    static var screenWithMouse: NSScreen? {
        screens.first { $0.frame.contains(NSEvent.mouseLocation) }
    }

    /// The display identifier of the screen.
    var displayID: CGDirectDisplayID {
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

        if let displayID = deviceDescription[screenNumberKey] as? CGDirectDisplayID {
            return displayID
        }

        if let displayID = deviceDescription[screenNumberKey] as? NSNumber {
            return CGDirectDisplayID(displayID.uint32Value)
        }

        preconditionFailure("Missing display identifier for screen")
    }

    /// A Boolean value that indicates whether the screen has a notch.
    var hasNotch: Bool {
        safeAreaInsets.top != 0
    }

    /// The frame of the screen's notch, if it has one.
    var frameOfNotch: CGRect? {
        guard
            let auxiliaryTopLeftArea,
            let auxiliaryTopRightArea
        else {
            return nil
        }
        return CGRect(
            x: auxiliaryTopLeftArea.maxX,
            y: frame.maxY - safeAreaInsets.top,
            width: auxiliaryTopRightArea.minX - auxiliaryTopLeftArea.maxX,
            height: safeAreaInsets.top
        )
    }

    /// Returns the height of the menu bar on this screen.
    func getMenuBarHeight() -> CGFloat? {
        let menuBarWindow = WindowInfo.getMenuBarWindow(for: displayID)
        return menuBarWindow?.frame.height
    }
}

// MARK: - NSStatusItem

extension NSStatusItem {
    /// Shows the given menu under the status item.
    @MainActor
    func showMenu(_ menu: NSMenu) {
        let originalMenu = self.menu
        defer {
            self.menu = originalMenu
        }
        self.menu = menu
        button?.performClick(nil)
    }
}

// MARK: - Publisher

extension Publisher {
    /// Transforms all elements from the upstream publisher into `Void` values.
    func mapToVoid() -> some Publisher<Void, Failure> {
        map { _ in () }
    }
}

// MARK: - Sequence where Element == MenuBarItem

extension Sequence where Element == MenuBarItem {
    /// Returns the menu bar items, sorted by their order in the menu bar.
    func sortedByOrderInMenuBar() -> [MenuBarItem] {
        sorted { lhs, rhs in
            lhs.frame.maxX < rhs.frame.maxX
        }
    }
}

// MARK: - TimeInterval

extension TimeInterval {
    /// A localized label for a duration expressed in seconds.
    var formattedSecondsLabel: LocalizedStringKey {
        let formattedValue = formatted()
        return if self == 1 {
            LocalizedStringKey(formattedValue + " second")
        } else {
            LocalizedStringKey(formattedValue + " seconds")
        }
    }
}
