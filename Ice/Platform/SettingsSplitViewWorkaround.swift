//
//  SettingsSplitViewWorkaround.swift
//  Ice
//

import AppKit

/// Installs private AppKit behavior needed by the settings window.
enum SettingsSplitViewWorkaround {
    static func install() {
        NSSplitViewItem.swizzle()
    }
}
