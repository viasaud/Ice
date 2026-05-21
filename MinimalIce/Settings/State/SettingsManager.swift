import Combine
import Cocoa

@MainActor
final class SettingsManager: ObservableObject {
    @Published var showOnClick = false
    @Published var showOnHover = true
    @Published var showSectionDividers = false
    @Published var enableAlwaysHiddenSection = false
    @Published var tempShowInterval: TimeInterval = 15

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

    var hiddenItemsActivationMode: HiddenItemsActivationMode {
        get {
            if showOnHover && !showOnClick {
                .hover
            } else {
                .click
            }
        }
        set {
            switch newValue {
            case .click:
                showOnClick = true
                showOnHover = false
            case .hover:
                showOnClick = false
                showOnHover = true
            }
        }
    }

    var behavior: SettingsBehavior {
        SettingsBehavior(
            hiddenItemsActivationMode: hiddenItemsActivationMode,
            showsSectionDividers: showSectionDividers,
            canRevealAlwaysHiddenSection: enableAlwaysHiddenSection,
            rehideInterval: tempShowInterval
        )
    }

    var revealPolicy: MenuBarRevealPolicy {
        MenuBarRevealPolicy(settings: behavior)
    }

    private func loadInitialState() {
        Defaults.ifPresent(key: .showOnClick, assign: &showOnClick)
        Defaults.ifPresent(key: .showOnHover, assign: &showOnHover)
        Defaults.ifPresent(key: .showSectionDividers, assign: &showSectionDividers)
        Defaults.ifPresent(key: .enableAlwaysHiddenSection, assign: &enableAlwaysHiddenSection)
        Defaults.ifPresent(key: .tempShowInterval, assign: &tempShowInterval)
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        $showOnClick
            .receive(on: DispatchQueue.main)
            .sink { showOnClick in
                Defaults.set(showOnClick, forKey: .showOnClick)
            }
            .store(in: &c)

        $showOnHover
            .receive(on: DispatchQueue.main)
            .sink { showOnHover in
                Defaults.set(showOnHover, forKey: .showOnHover)
            }
            .store(in: &c)

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

        $tempShowInterval
            .receive(on: DispatchQueue.main)
            .sink { interval in
                Defaults.set(interval, forKey: .tempShowInterval)
            }
            .store(in: &c)

        cancellables = c
    }

    private func hideAlwaysHiddenSection() {
        appState?.menuBarManager.section(withName: .alwaysHidden)?.hide()
    }
}

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
        let rehideDelay = settings.revealsHiddenItemsOnClick ? nil : settings.rehideInterval

        if modifierFlags.contains(.option) {
            guard canRevealAlwaysHiddenSection else {
                return .none
            }
            return .toggle(section: .alwaysHidden, rehideAfter: rehideDelay)
        }

        if preferredSectionName == .alwaysHidden, !canRevealAlwaysHiddenSection {
            return .none
        }

        return .toggle(section: preferredSectionName ?? .hidden, rehideAfter: rehideDelay)
    }

    func canShowDuringCommandDrag(_ sectionName: MenuBarSection.Name) -> Bool {
        sectionName != .alwaysHidden || canRevealAlwaysHiddenSection
    }

    func contextMenuSectionNames() -> [MenuBarSection.Name] {
        canRevealAlwaysHiddenSection ? [.hidden, .alwaysHidden] : [.hidden]
    }
}
