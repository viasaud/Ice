//
//  MenuBarItemManager.swift
//  Ice
//

import Cocoa
import Combine

/// Manager for menu bar items.
@MainActor
final class MenuBarItemManager: ObservableObject {
    /// The manager's menu bar item cache.
    @Published private(set) var itemCache = ItemCache()

    /// The shared app state.
    private(set) weak var appState: AppState?

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// The current menu bar item cache refresh task, if one is running.
    private var cacheRefreshTask: Task<Void, Never>?

    /// A Boolean value that indicates whether another cache refresh was requested
    /// while the current refresh task was running.
    private var isCacheRefreshPending = false

    /// Cached window identifiers for the most recent items.
    var cachedItemWindowIDs = [CGWindowID]()

    /// Context values for the current temporarily shown items.
    var tempShownItemContexts = [TempShownItemContext]()

    /// A timer that determines when to rehide the temporarily shown items.
    var tempShownItemsTimer: Timer?

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
        static let rehideRetryInterval: TimeInterval = 3
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

    /// Replaces the cached menu bar item snapshot.
    func replaceItemCache(with cache: ItemCache) {
        itemCache = cache
    }

    /// Clears the cached menu bar item snapshot.
    func clearItemCache() {
        itemCache.clear()
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
                requestItemCacheRefresh()
            }
            .store(in: &c)

        NSWorkspace.shared.publisher(for: \.runningApplications)
            .delay(for: 0.25, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                requestItemCacheRefresh()
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

    private func requestItemCacheRefresh() {
        guard cacheRefreshTask == nil else {
            isCacheRefreshPending = true
            return
        }

        isCacheRefreshPending = true
        cacheRefreshTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            repeat {
                isCacheRefreshPending = false
                await cacheItemsIfNeeded()
            } while isCacheRefreshPending

            cacheRefreshTask = nil
        }
    }
}

extension Logger {
    /// The logger to use for the menu bar item manager.
    static let itemManager = Logger(category: "MenuBarItemManager")
}
