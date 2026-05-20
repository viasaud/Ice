//
//  PermissionGate.swift
//  Ice
//

/// Value surface for deciding whether the app may enter normal operation.
struct PermissionGate: Equatable {
    var hasRequiredPermissions: Bool

    var canRunApp: Bool {
        hasRequiredPermissions
    }
}
