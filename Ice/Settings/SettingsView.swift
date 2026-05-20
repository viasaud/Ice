//
//  SettingsView.swift
//  Ice
//

import LaunchAtLogin
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    private let contentWidth: CGFloat = 640

    private var generalManager: GeneralSettingsManager {
        appState.settingsManager.generalSettingsManager
    }

    private var advancedManager: AdvancedSettingsManager {
        appState.settingsManager.advancedSettingsManager
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            LaunchAtLogin.isEnabled
        } set: { isEnabled in
            LaunchAtLogin.isEnabled = isEnabled
        }
    }

    private var hiddenItemsActivationMode: Binding<HiddenItemsActivationMode> {
        Binding {
            if generalManager.showOnHover && !generalManager.showOnClick {
                .hover
            } else {
                .click
            }
        } set: { mode in
            switch mode {
            case .click:
                generalManager.showOnClick = true
                generalManager.showOnHover = false
            case .hover:
                generalManager.showOnClick = false
                generalManager.showOnHover = true
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            MinimalSettingsTitle()
            startupSection
            menuBarSection
            advancedSection
            aboutSection
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 32)
        .background(.windowBackground)
        .preferredColorScheme(.dark)
        .font(.body)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var startupSection: some View {
        settingsSection("Startup") {
            SettingsRow("Open at login") {
                Toggle("Open at login", isOn: launchAtLoginBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }

            SettingsRow("Show menu bar icon") {
                Toggle("Show menu bar icon", isOn: generalManager.bindings.showIceIcon)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
        }
    }

    @ViewBuilder
    private var menuBarSection: some View {
        settingsSection("Menu Bar") {
            if advancedManager.enableAlwaysHiddenSection {
                SettingsRowWithNote("Reveal hidden menu bar items by", note: alwaysHiddenSectionDescription) {
                    Picker("Reveal hidden menu bar items by", selection: hiddenItemsActivationMode) {
                        ForEach(HiddenItemsActivationMode.allCases) { mode in
                            Text(mode.localized).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .fixedSize()
                }
            } else {
                SettingsRow("Reveal hidden menu bar items by") {
                    Picker("Reveal hidden menu bar items by", selection: hiddenItemsActivationMode) {
                        ForEach(HiddenItemsActivationMode.allCases) { mode in
                            Text(mode.localized).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .fixedSize()
                }
            }
        }
    }

    @ViewBuilder
    private var advancedSection: some View {
        settingsSection("Advanced") {
            SettingsRow("Show dividers between sections") {
                Toggle("Show dividers between sections", isOn: advancedManager.bindings.showSectionDividers)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }

            SettingsRow("Use an always-hidden section") {
                Toggle("Use an always-hidden section", isOn: advancedManager.bindings.enableAlwaysHiddenSection)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }

            SettingsRow("Hide click-revealed items after") {
                IceSlider(
                    formattedToSeconds(advancedManager.tempShowInterval),
                    value: advancedManager.bindings.tempShowInterval,
                    in: 0...30,
                    step: 1
                )
                .frame(width: 260)
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        settingsSection("About") {
            SettingsRow("Ice") {
                Text(Constants.versionString)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.leading, 12)

            SettingsCard {
                content()
            }
        }
    }

    private var alwaysHiddenSectionDescription: LocalizedStringKey {
        "To reveal the always-hidden section, Option-click the chevron."
    }

    private func formattedToSeconds(_ interval: TimeInterval) -> LocalizedStringKey {
        let formatted = interval.formatted()
        return if interval == 1 {
            LocalizedStringKey(formatted + " second")
        } else {
            LocalizedStringKey(formatted + " seconds")
        }
    }

}

private enum HiddenItemsActivationMode: String, CaseIterable, Identifiable {
    case click
    case hover

    var id: Self { self }

    var localized: LocalizedStringKey {
        switch self {
        case .click:
            "Click"
        case .hover:
            "Hover"
        }
    }
}

private struct MinimalSettingsTitle: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Text(verbatim: "$")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)

                Text("settings")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            Text("Controls for revealing and hiding menu bar items.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 2)
    }
}

private struct SettingsRow<Label: View, Control: View>: View {
    private let label: Label
    private let control: Control

    init(
        @ViewBuilder label: () -> Label,
        @ViewBuilder control: () -> Control
    ) {
        self.label = label()
        self.control = control()
    }

    init(
        _ title: LocalizedStringKey,
        @ViewBuilder control: () -> Control
    ) where Label == Text {
        self.init {
            Text(title)
        } control: {
            control()
        }
    }

    init(
        _ title: String,
        @ViewBuilder control: () -> Control
    ) where Label == Text {
        self.init {
            Text(verbatim: title)
        } control: {
            control()
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            label
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            control
                .font(.system(size: 14, weight: .regular))
                .frame(alignment: .trailing)
                .layoutPriority(1)
        }
        .frame(minHeight: 28)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}

private struct SettingsNote: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .padding(.trailing, 128)
            .padding(.top, 0)
            .padding(.bottom, 4)
    }
}

private struct SettingsRowWithNote<Control: View>: View {
    let title: LocalizedStringKey
    let note: LocalizedStringKey
    let control: Control

    init(
        _ title: LocalizedStringKey,
        note: LocalizedStringKey,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.note = note
        self.control = control()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(title) {
                control
            }

            SettingsNote(note)
                .padding(.top, -2)
        }
    }
}
