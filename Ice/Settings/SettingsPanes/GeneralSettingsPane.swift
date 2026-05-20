//
//  GeneralSettingsPane.swift
//  Ice
//

import LaunchAtLogin
import SwiftUI

// Legacy settings pane retained for reference only. SettingsView is the active macOS 26 settings UI.
struct GeneralSettingsPane: View {
    @EnvironmentObject var appState: AppState

    private var manager: GeneralSettingsManager {
        appState.settingsManager.generalSettingsManager
    }

    var body: some View {
        IceForm {
            IceSection {
                launchAtLogin
            }
            IceSection {
                iceIconOptions
            }
            IceSection {
                showOnClick
                showOnHover
            }
        }
    }

    @ViewBuilder
    private var launchAtLogin: some View {
        LaunchAtLogin.Toggle()
    }

    @ViewBuilder
    private var iceIconOptions: some View {
        Toggle("Show menu bar icon", isOn: manager.bindings.showIceIcon)
            .annotation {
                if !manager.showIceIcon {
                    Text("You can still open settings by right-clicking an empty area in the menu bar")
                }
            }
    }

    @ViewBuilder
    private var showOnClick: some View {
        Toggle("Reveal hidden menu bar items on click", isOn: manager.bindings.showOnClick)
            .annotation("Click an empty area of the menu bar to reveal hidden items")
    }

    @ViewBuilder
    private var showOnHover: some View {
        Toggle("Reveal hidden menu bar items on hover", isOn: manager.bindings.showOnHover)
            .annotation("Hover over an empty area of the menu bar to reveal hidden items")
    }

}
