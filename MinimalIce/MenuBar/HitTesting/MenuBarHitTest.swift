//
//  MenuBarHitTest.swift
//  Ice
//

/// A value snapshot of the pointer's relationship to the menu bar.
struct MenuBarHitTest: Equatable {
    var isInsideMenuBar: Bool
    var isInsideApplicationMenu: Bool
    var isInsideMenuBarItem: Bool
    var isInsideNotch: Bool
    var isInsideIceIcon: Bool

    var isInsideEmptyMenuBarSpace: Bool {
        isInsideMenuBar &&
        !isInsideApplicationMenu &&
        !isInsideMenuBarItem &&
        !isInsideNotch
    }

    var isInsideHoverActivationRegion: Bool {
        isInsideIceIcon
    }
}
