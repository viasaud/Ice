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
