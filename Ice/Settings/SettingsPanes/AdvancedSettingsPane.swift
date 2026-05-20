//
//  AdvancedSettingsPane.swift
//  Ice
//

import SwiftUI

// Legacy settings pane retained for reference only. SettingsView is the active macOS 26 settings UI.
struct AdvancedSettingsPane: View {
    @EnvironmentObject var appState: AppState
    @State private var maxSliderLabelWidth: CGFloat = 0

    private var menuBarManager: MenuBarManager {
        appState.menuBarManager
    }

    private var manager: AdvancedSettingsManager {
        appState.settingsManager.advancedSettingsManager
    }

    private func formattedToSeconds(_ interval: TimeInterval) -> LocalizedStringKey {
        let formatted = interval.formatted()
        return if interval == 1 {
            LocalizedStringKey(formatted + " second")
        } else {
            LocalizedStringKey(formatted + " seconds")
        }
    }

    var body: some View {
        IceForm {
            IceSection {
                showSectionDividers
                showContextMenuOnRightClick
            }
            IceSection {
                enableAlwaysHiddenSection
                canToggleAlwaysHiddenSection
            }
            IceSection {
                tempShowIntervalSlider
            }
        }
    }

    @ViewBuilder
    private var showSectionDividers: some View {
        Toggle("Show dividers between sections", isOn: manager.bindings.showSectionDividers)
            .annotation {
                HStack(spacing: 2) {
                    Text("Insert divider items")
                    if let nsImage = ControlItemImage.builtin(.chevronLarge).nsImage(for: appState) {
                        HStack(spacing: 0) {
                            Text("(")
                                .font(.body.monospaced().bold())
                            Image(nsImage: nsImage)
                                .padding(.horizontal, -2)
                            Text(")")
                                .font(.body.monospaced().bold())
                        }
                    }
                    Text("between sections")
                }
            }
    }

    @ViewBuilder
    private var enableAlwaysHiddenSection: some View {
        Toggle("Use an always-hidden section", isOn: manager.bindings.enableAlwaysHiddenSection)
    }

    @ViewBuilder
    private var canToggleAlwaysHiddenSection: some View {
        if manager.enableAlwaysHiddenSection {
            Toggle("Allow the always-hidden section to be revealed", isOn: manager.bindings.canToggleAlwaysHiddenSection)
                .annotation {
                    if appState.settingsManager.generalSettingsManager.showOnClick {
                        Text("To reveal the always-hidden section, Option-click the chevron or an empty menu bar area")
                    } else {
                        Text("To reveal the always-hidden section, Option-click the chevron")
                    }
                }
        }
    }

    @ViewBuilder
    private var tempShowIntervalSlider: some View {
        IceLabeledContent {
            IceSlider(
                formattedToSeconds(manager.tempShowInterval),
                value: manager.bindings.tempShowInterval,
                in: 0...30,
                step: 1
            )
        } label: {
            Text("Hide click-revealed items after")
                .frame(minHeight: .compactSliderMinHeight)
                .frame(minWidth: maxSliderLabelWidth, alignment: .leading)
                .onFrameChange { frame in
                    maxSliderLabelWidth = max(maxSliderLabelWidth, frame.width)
                }
        }
        .annotation("How long click-revealed menu bar items stay visible before hiding again")
    }

    @ViewBuilder
    private var showContextMenuOnRightClick: some View {
        Toggle("Open menu on right-click", isOn: manager.bindings.showContextMenuOnRightClick)
    }
}

#Preview {
    AdvancedSettingsPane()
        .fixedSize()
        .environmentObject(AppState())
}
