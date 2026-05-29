//
//  MenuBarItemManager.swift
//  Ice
//

import Cocoa
import Combine

/// Manager for menu bar items.
@MainActor
final class MenuBarItemManager {
    /// The shared app state.
    private(set) weak var appState: AppState?

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// The current control item order check task, if one is running.
    private var controlItemOrderCheckTask: Task<Void, Never>?

    /// A Boolean value that indicates whether another order check was requested
    /// while the current check task was running.
    private var isControlItemOrderCheckPending = false

    /// Window identifiers from the most recent control item order check.
    var lastObservedMenuBarItemWindowIDs = [CGWindowID]()

    /// The last time a menu bar item was moved.
    var lastItemMoveStartDate: Date?

    /// The last time the mouse was moved.
    var lastMouseMoveStartDate: Date?

    /// Counter to determine if a menu bar item, or group of menu bar
    /// items is being moved.
    var itemMoveCount = 0

    /// A Boolean value that indicates whether a mouse button is down.
    var isMouseButtonDown = false

    /// Event type mask for tracking mouse events.
    private let mouseTrackingMask: NSEvent.EventTypeMask = [
        .mouseMoved,
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
        .leftMouseUp,
        .rightMouseUp,
        .otherMouseUp,
    ]

    enum Timing {
        static let recentMovementThreshold: TimeInterval = 1
        static let pollingInterval: Duration = .milliseconds(10)
        static let eventReceiptTimeout: Duration = .milliseconds(50)
        static let frameFallbackDelay: Duration = .milliseconds(50)
    }

    /// A Boolean value that indicates whether a menu bar item, or
    /// group of menu bar items is being moved.
    var isMovingItem: Bool {
        itemMoveCount > 0
    }

    /// A Boolean value that indicates whether a menu bar item has
    /// recently moved.
    var itemHasRecentlyMoved: Bool {
        guard let lastItemMoveStartDate else {
            return false
        }
        return Date.now.timeIntervalSince(lastItemMoveStartDate) <= Timing.recentMovementThreshold
    }

    /// A Boolean value that indicates whether the mouse has recently moved.
    var mouseHasRecentlyMoved: Bool {
        guard let lastMouseMoveStartDate else {
            return false
        }
        return Date.now.timeIntervalSince(lastMouseMoveStartDate) <= Timing.recentMovementThreshold
    }

    /// Creates a manager with the given app state.
    init(appState: AppState) {
        self.appState = appState
    }

    /// Sets up the manager.
    func performSetup() {
        configureCancellables()
    }

    /// Configures the internal observers for the manager.
    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        Timer.publish(every: 5, on: .main, in: .default)
            .autoconnect()
            .merge(with: Just(.now))
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                requestControlItemOrderCheck()
            }
            .store(in: &c)

        NSWorkspace.shared.publisher(for: \.runningApplications)
            .delay(for: 0.25, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                requestControlItemOrderCheck()
            }
            .store(in: &c)

        Publishers.Merge(
            UniversalEventMonitor.publisher(for: mouseTrackingMask),
            RunLoopLocalEventMonitor.publisher(for: mouseTrackingMask, mode: .eventTracking)
        )
        .removeDuplicates()
        .sink { [weak self] event in
            guard let self else {
                return
            }
            switch event.type {
            case .mouseMoved:
                lastMouseMoveStartDate = .now
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                isMouseButtonDown = true
            case .leftMouseUp, .rightMouseUp, .otherMouseUp:
                isMouseButtonDown = false
            default:
                break
            }
        }
        .store(in: &c)

        cancellables = c
    }

    private func requestControlItemOrderCheck() {
        guard controlItemOrderCheckTask == nil else {
            isControlItemOrderCheckPending = true
            return
        }

        isControlItemOrderCheckPending = true
        controlItemOrderCheckTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            repeat {
                isControlItemOrderCheckPending = false
                await repairControlItemOrderIfNeeded()
            } while isControlItemOrderCheckPending

            controlItemOrderCheckTask = nil
        }
    }
}

extension Logger {
    /// The logger to use for the menu bar item manager.
    static let itemManager = Logger(category: "MenuBarItemManager")
}
