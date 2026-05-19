//
//  KeyCode.swift
//  Ice
//

import Carbon.HIToolbox

/// Lightweight representation of local keyboard event key codes.
struct KeyCode: Hashable, RawRepresentable {
    let rawValue: Int

    static let `return` = KeyCode(rawValue: kVK_Return)
    static let delete = KeyCode(rawValue: kVK_Delete)
    static let escape = KeyCode(rawValue: kVK_Escape)
    static let downArrow = KeyCode(rawValue: kVK_DownArrow)
    static let upArrow = KeyCode(rawValue: kVK_UpArrow)
}
