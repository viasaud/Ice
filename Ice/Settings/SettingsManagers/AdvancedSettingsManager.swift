//
//  AdvancedSettingsManager.swift
//  Ice
//

import Combine
import Foundation

@MainActor
final class AdvancedSettingsManager: ObservableObject {
    /// A Boolean value that indicates whether section divider control
    /// items should be shown.
    @Published var showSectionDividers = false

    /// A Boolean value that indicates whether the always-hidden section
    /// is enabled.
    @Published var enableAlwaysHiddenSection = false

    /// A Boolean value that indicates whether the always-hidden section
    /// can be toggled by holding down the Option key.
    @Published var canToggleAlwaysHiddenSection = true

    /// Time interval to temporarily show items for.
    @Published var tempShowInterval: TimeInterval = 15

    @Published var showContextMenuOnRightClick = true

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// The shared app state.
    private(set) weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    func performSetup() {
        loadInitialState()
        configureCancellables()
    }

    private func loadInitialState() {
        Defaults.ifPresent(key: .showSectionDividers, assign: &showSectionDividers)
        Defaults.ifPresent(key: .enableAlwaysHiddenSection, assign: &enableAlwaysHiddenSection)
        Defaults.ifPresent(key: .canToggleAlwaysHiddenSection, assign: &canToggleAlwaysHiddenSection)
        Defaults.ifPresent(key: .tempShowInterval, assign: &tempShowInterval)
        Defaults.ifPresent(key: .showContextMenuOnRightClick, assign: &showContextMenuOnRightClick)
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        $showSectionDividers
            .receive(on: DispatchQueue.main)
            .sink { shouldShow in
                Defaults.set(shouldShow, forKey: .showSectionDividers)
            }
            .store(in: &c)

        $enableAlwaysHiddenSection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enable in
                Defaults.set(enable, forKey: .enableAlwaysHiddenSection)
                if !enable {
                    self?.hideAlwaysHiddenSection()
                }
            }
            .store(in: &c)

        $canToggleAlwaysHiddenSection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canToggle in
                Defaults.set(canToggle, forKey: .canToggleAlwaysHiddenSection)
                if !canToggle {
                    self?.hideAlwaysHiddenSection()
                }
            }
            .store(in: &c)

        $tempShowInterval
            .receive(on: DispatchQueue.main)
            .sink { interval in
                Defaults.set(interval, forKey: .tempShowInterval)
            }
            .store(in: &c)

        $showContextMenuOnRightClick
            .receive(on: DispatchQueue.main)
            .sink { showAll in
                Defaults.set(showAll, forKey: .showContextMenuOnRightClick)
            }
            .store(in: &c)

        cancellables = c
    }

    private func hideAlwaysHiddenSection() {
        appState?.menuBarManager.section(withName: .alwaysHidden)?.hide()
    }
}

// MARK: AdvancedSettingsManager: BindingExposable
extension AdvancedSettingsManager: BindingExposable { }
