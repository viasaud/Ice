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

    /// Returns the data for the specified key.
    ///
    /// - Parameter key: The key in the UserDefaults database
    ///   to retrieve the value for.
    static func data(forKey key: Key) -> Data? {
        UserDefaults.standard.data(forKey: key.rawValue)
    }

    /// Returns the Boolean value for the specified key.
    ///
    /// - Parameter key: The key in the UserDefaults database
    ///   to retrieve the value for.
    static func bool(forKey key: Key) -> Bool {
        UserDefaults.standard.bool(forKey: key.rawValue)
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

        // MARK: Permissions

        case hasAccessibilityPermission = "HasAccessibilityPermission"

        // MARK: Advanced Settings

        case showSectionDividers = "ShowSectionDividers"
        case enableAlwaysHiddenSection = "EnableAlwaysHiddenSection"
        case tempShowInterval = "TempShowInterval"

        // MARK: Migration

        case hasMigrated0_8_0 = "hasMigrated0_8_0"
        case hasMigrated0_10_0 = "hasMigrated0_10_0"
        case hasMigrated0_10_1 = "hasMigrated0_10_1"

        // MARK: Deprecated

        case sections = "Sections"
    }
}

enum StatusItemDefaults {
    static subscript<Value>(key: Key<Value>, autosaveName: String) -> Value? {
        get {
            UserDefaults.standard.object(forKey: key.stringKey(for: autosaveName)) as? Value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key.stringKey(for: autosaveName))
        }
    }

    static func migrate<Value>(key: Key<Value>, from oldAutosaveName: String, to newAutosaveName: String) {
        guard newAutosaveName != oldAutosaveName else {
            return
        }
        Self[key, newAutosaveName] = Self[key, oldAutosaveName]
        Self[key, oldAutosaveName] = nil
    }

    struct Key<Value> {
        let rawValue: String

        func stringKey(for autosaveName: String) -> String {
            "NSStatusItem \(rawValue) \(autosaveName)"
        }
    }
}

extension StatusItemDefaults.Key<CGFloat> {
    static let preferredPosition = Self(rawValue: "Preferred Position")
}

extension StatusItemDefaults.Key<Bool> {
    static let visible = Self(rawValue: "Visible")
}
