//
//  SettingsBehavior.swift
//  Ice
//

import Foundation

/// The user-selected way hidden menu bar items are revealed.
enum HiddenItemsActivationMode: String, CaseIterable, Identifiable {
    case click
    case hover

    var id: Self { self }

    var displayTitle: String {
        switch self {
        case .click:
            "Click"
        case .hover:
            "Hover"
        }
    }
}

/// A value snapshot of settings that drive menu bar behavior.
struct SettingsBehavior: Equatable {
    var hiddenItemsActivationMode: HiddenItemsActivationMode
    var showsSectionDividers: Bool
    var canRevealAlwaysHiddenSection: Bool
    var rehideInterval: TimeInterval

    var revealsHiddenItemsOnClick: Bool {
        hiddenItemsActivationMode == .click
    }

    var revealsHiddenItemsOnHover: Bool {
        hiddenItemsActivationMode == .hover
    }
}

extension SettingsManager {
    var hiddenItemsActivationMode: HiddenItemsActivationMode {
        get {
            if generalSettingsManager.showOnHover && !generalSettingsManager.showOnClick {
                .hover
            } else {
                .click
            }
        }
        set {
            switch newValue {
            case .click:
                generalSettingsManager.showOnClick = true
                generalSettingsManager.showOnHover = false
            case .hover:
                generalSettingsManager.showOnClick = false
                generalSettingsManager.showOnHover = true
            }
        }
    }

    var behavior: SettingsBehavior {
        SettingsBehavior(
            hiddenItemsActivationMode: hiddenItemsActivationMode,
            showsSectionDividers: advancedSettingsManager.showSectionDividers,
            canRevealAlwaysHiddenSection: advancedSettingsManager.enableAlwaysHiddenSection,
            rehideInterval: advancedSettingsManager.tempShowInterval
        )
    }

    var revealPolicy: MenuBarRevealPolicy {
        MenuBarRevealPolicy(settings: behavior)
    }
}
