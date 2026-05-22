import Combine
import Cocoa

@MainActor
final class SettingsManager: ObservableObject {
    @Published private(set) var hiddenItemsActivationMode: HiddenItemsActivationMode = .hover {
        didSet {
            Defaults.set(hiddenItemsActivationMode == .click, forKey: .showOnClick)
            Defaults.set(hiddenItemsActivationMode == .hover, forKey: .showOnHover)
        }
    }

    @Published private(set) var enableAlwaysHiddenSection = false {
        didSet {
            Defaults.set(enableAlwaysHiddenSection, forKey: .enableAlwaysHiddenSection)
            if hasPerformedSetup, !enableAlwaysHiddenSection {
                hideAlwaysHiddenSection()
            }
        }
    }

    @Published private(set) var tempShowInterval: TimeInterval = 15 {
        didSet { Defaults.set(tempShowInterval, forKey: .tempShowInterval) }
    }

    /// The shared app state.
    private(set) weak var appState: AppState?

    private var hasPerformedSetup = false

    init(appState: AppState) {
        self.appState = appState
    }

    func performSetup() {
        guard !hasPerformedSetup else {
            return
        }
        loadInitialState()
        hasPerformedSetup = true
    }

    private func loadInitialState() {
        var showOnClick = false
        var showOnHover = true
        Defaults.ifPresent(key: .showOnClick, assign: &showOnClick)
        Defaults.ifPresent(key: .showOnHover, assign: &showOnHover)
        hiddenItemsActivationMode = showOnHover && !showOnClick ? .hover : .click
        Defaults.ifPresent(key: .enableAlwaysHiddenSection, assign: &enableAlwaysHiddenSection)
        Defaults.ifPresent(key: .tempShowInterval, assign: &tempShowInterval)
    }

    func setHiddenItemsActivationMode(_ mode: HiddenItemsActivationMode) {
        hiddenItemsActivationMode = mode
    }

    func toggleAlwaysHiddenSection() {
        enableAlwaysHiddenSection.toggle()
    }

    func setTempShowInterval(_ interval: TimeInterval) {
        tempShowInterval = interval
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
}
