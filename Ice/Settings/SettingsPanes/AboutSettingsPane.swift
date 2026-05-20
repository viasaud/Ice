//
//  AboutSettingsPane.swift
//  Ice
//

import SwiftUI

// Legacy settings pane retained for reference only. SettingsView is the active macOS 26 settings UI.
struct AboutSettingsPane: View {
    var body: some View {
        IceForm {
            IceSection {
                IceLabeledContent {
                    Text(Constants.versionString)
                        .foregroundStyle(.secondary)
                } label: {
                    Text("Ice")
                }
            }
        }
    }
}
