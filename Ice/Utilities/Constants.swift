//
//  Constants.swift
//  Ice
//

import Foundation

enum Constants {
    /// The version string in the app's bundle.
    static let versionString = Bundle.main.requiredVersionString

    /// The bundle identifier of the app.
    static let bundleIdentifier = Bundle.main.requiredBundleIdentifier

    /// The identifier for the settings window.
    static let settingsWindowID = "SettingsWindow"

    /// The identifier for the permissions window.
    static let permissionsWindowID = "PermissionsWindow"

    /// The title for the settings window.
    static let settingsWindowTitle = "Ice"

    /// The title for the permissions window.
    static let permissionsWindowTitle = "Permissions"
}

private extension Bundle {
    var requiredVersionString: String {
        requiredString(forInfoDictionaryKey: "CFBundleShortVersionString")
    }

    var requiredBundleIdentifier: String {
        guard let bundleIdentifier else {
            preconditionFailure("Missing required bundle identifier")
        }
        return bundleIdentifier
    }

    func requiredString(forInfoDictionaryKey key: String) -> String {
        guard let value = object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            preconditionFailure("Missing required bundle string for \(key)")
        }
        return value
    }
}
