//
//  Defaults.swift
//  Ice
//

import Cocoa

enum Defaults {
    /// Returns a dictionary containing the keys and values for
    /// the defaults meant to be seen by all applications.
    static var globalDomain: [String: Any] {
        UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain) ?? [:]
    }

    /// Returns the object for the specified key.
    ///
    /// - Parameter key: The key in the UserDefaults database
    ///   to retrieve the value for.
    static func object(forKey key: Key) -> Any? {
        UserDefaults.standard.object(forKey: key.rawValue)
    }

    /// Sets the value for the specified key.
    ///
    /// - Parameter key: The key in the UserDefaults database
    ///   to set the value for.
    static func set(_ value: Any?, forKey key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    /// Retrieves the value for the given key, and, if it is
    /// present, assigns it to the given `inout` parameter.
    static func ifPresent<Value>(key: Key, assign value: inout Value) {
        if let found = object(forKey: key) as? Value {
            value = found
        }
    }

}

extension Defaults {
    enum Key: String {

        // MARK: General Settings

        case showOnClick = "ShowOnClick"
        case showOnHover = "ShowOnHover"

        // MARK: Advanced Settings

        case enableAlwaysHiddenSection = "EnableAlwaysHiddenSection"
        case tempShowInterval = "TempShowInterval"
    }
}

extension Defaults {
    static func statusItemPreferredPosition(for autosaveName: String) -> CGFloat? {
        UserDefaults.standard.object(forKey: statusItemKey("Preferred Position", autosaveName)) as? CGFloat
    }

    static func setStatusItemPreferredPosition(_ value: CGFloat?, for autosaveName: String) {
        UserDefaults.standard.set(value, forKey: statusItemKey("Preferred Position", autosaveName))
    }

    private static func statusItemKey(_ name: String, _ autosaveName: String) -> String {
        "NSStatusItem \(name) \(autosaveName)"
    }
}
