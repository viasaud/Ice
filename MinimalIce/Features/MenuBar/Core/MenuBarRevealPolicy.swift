//
//  MenuBarRevealPolicy.swift
//  Ice
//

import Cocoa

/// Owns the rules for revealing menu bar sections.
struct MenuBarRevealPolicy {
    enum Decision: Equatable {
        case toggle(section: MenuBarSection.Name, rehideAfter: TimeInterval?)
        case none
    }

    let settings: SettingsBehavior

    var canRevealAlwaysHiddenSection: Bool {
        settings.canRevealAlwaysHiddenSection
    }

    func toggleDecision(
        modifierFlags: NSEvent.ModifierFlags,
        preferredSectionName: MenuBarSection.Name?
    ) -> Decision {
        if modifierFlags.contains(.option) {
            guard canRevealAlwaysHiddenSection else {
                return .none
            }
            return .toggle(section: .alwaysHidden, rehideAfter: settings.rehideInterval)
        }

        if preferredSectionName == .alwaysHidden, !canRevealAlwaysHiddenSection {
            return .none
        }

        return .toggle(section: preferredSectionName ?? .hidden, rehideAfter: settings.rehideInterval)
    }

    func canShowDuringCommandDrag(_ sectionName: MenuBarSection.Name) -> Bool {
        sectionName != .alwaysHidden || canRevealAlwaysHiddenSection
    }

    func contextMenuSectionNames() -> [MenuBarSection.Name] {
        canRevealAlwaysHiddenSection ? [.hidden, .alwaysHidden] : [.hidden]
    }
}
