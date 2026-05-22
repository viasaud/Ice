import CoreGraphics

extension MenuBarItemManager {
    /// Cache for menu bar items.
    struct ItemCache: Hashable {
        /// All cached menu bar items, keyed by section.
        private var items = [MenuBarSection.Name: [MenuBarItem]]()

        /// All cached menu bar items.
        var allItems: [MenuBarItem] {
            MenuBarSection.Name.allCases.reduce(into: []) { result, section in
                result.append(contentsOf: self[section])
            }
        }

        /// The cached menu bar items managed by Ice.
        var managedItems: [MenuBarItem] {
            MenuBarSection.Name.allCases.reduce(into: []) { result, section in
                result.append(contentsOf: managedItems(for: section))
            }
        }

        /// Clears the cache.
        mutating func clear() {
            items.removeAll()
        }

        /// Returns the cached menu bar items managed by Ice for the given section.
        func managedItems(for section: MenuBarSection.Name) -> [MenuBarItem] {
            self[section].filter { item in
                // Filter out items that can't be hidden.
                guard item.canBeHidden else {
                    return false
                }

                if item.owningApplication == .current {
                    // Ice icon is the only item owned by Ice that should be included.
                    guard item.title == ControlItem.Identifier.iceIcon.rawValue else {
                        return false
                    }
                }

                return true
            }
        }

        /// Accesses the items in the given section.
        subscript(section: MenuBarSection.Name) -> [MenuBarItem] {
            get { items[section, default: []] }
            set { items[section] = newValue }
        }
    }
}

// MARK: - Cache Items


extension MenuBarItemManager {
    /// Logs a reason for skipping the cache.
    func logSkippingCache(reason: String) {
        Logger.itemManager.debug("Skipping menu bar item cache as \(reason)")
    }

    private func cache(_ snapshot: ObservedMenuBarSnapshot) {
        Logger.itemManager.debug("Caching menu bar items")
        let result = snapshot.makeCache(restoring: tempShownItemContexts)
        for item in result.uncachedItems {
            Logger.itemManager.warning("\(item.logString) was not cached")
        }
        replaceItemCache(with: result.cache)
    }

    /// Caches the current menu bar items if needed, ensuring that the control
    /// items are in the correct order.
    func cacheItemsIfNeeded() async {
        do {
            try await waitForItemsToStopMoving(timeout: .seconds(1))
        } catch is TaskTimeoutError {
            logSkippingCache(reason: "an item is currently being moved")
            return
        } catch {
            guard !itemHasRecentlyMoved else {
                logSkippingCache(reason: "an item was recently moved")
                return
            }
        }

        let itemWindowIDs = WindowServerAdapter.activeSpaceMenuBarItemWindowIDs
        if cachedItemWindowIDs == itemWindowIDs {
            logSkippingCache(reason: "item windows have not changed")
            return
        } else {
            cachedItemWindowIDs = itemWindowIDs
        }

        guard let snapshot = ObservedMenuBarSnapshot(items: MenuBarItem.getMenuBarItems(onScreenOnly: false, activeSpaceOnly: true)) else {
            Logger.itemManager.warning("Missing control item for hidden section")
            Logger.itemManager.debug("Clearing menu bar item cache")
            clearItemCache()
            return
        }

        do {
            try await enforceControlItemOrderIfNeeded(in: snapshot)
            cache(snapshot)
        } catch {
            Logger.itemManager.error("Error enforcing control item order: \(error)")
            Logger.itemManager.debug("Clearing menu bar item cache")
            clearItemCache()
        }
    }
}



extension MenuBarItemManager {
    /// Enforces the order of the given control items, ensuring that the always-hidden
    /// control item stays to the left of the hidden control item.
    ///
    /// - Parameters:
    ///   - hiddenControlItem: A menu bar item that represents the control item for the
    ///     hidden section.
    ///   - alwaysHiddenControlItem: A menu bar item that represents the control item
    ///     for the always-hidden section.
    private func enforceControlItemOrderIfNeeded(in snapshot: ObservedMenuBarSnapshot) async throws {
        guard
            let alwaysHiddenControlItem = snapshot.alwaysHiddenControlItem,
            snapshot.needsControlItemOrderRepair
        else {
            return
        }

        guard !isMouseButtonDown else {
            Logger.itemManager.debug("Mouse button is down, so will not enforce control item order")
            return
        }
        guard !mouseHasRecentlyMoved else {
            Logger.itemManager.debug("Mouse has recently moved, so will not enforce control item order")
            return
        }
        Logger.itemManager.info("Arranging menu bar items")
        try await slowMove(item: alwaysHiddenControlItem, to: .leftOfItem(snapshot.hiddenControlItem))
    }
}

private struct ObservedMenuBarSnapshot {
    let hiddenControlItem: MenuBarItem
    let visibleControlItem: MenuBarItem
    let alwaysHiddenControlItem: MenuBarItem?
    let otherItems: [MenuBarItem]

    private var topology: SectionTopology {
        SectionTopology(
            visibleControlItemFrame: visibleControlItem.frame,
            alwaysHiddenControlItemFrame: alwaysHiddenControlItem?.frame
        )
    }

    var needsControlItemOrderRepair: Bool {
        guard let alwaysHiddenControlItem else {
            return false
        }
        return hiddenControlItem.frame.maxX <= alwaysHiddenControlItem.frame.minX
    }

    init?(items: [MenuBarItem]) {
        var otherItems = items
        guard let hiddenControlItem = otherItems.firstIndex(matching: .hiddenControlItem).map({ otherItems.remove(at: $0) }) else {
            return nil
        }
        guard let visibleControlItem = otherItems.firstIndex(matching: .iceIcon).map({ otherItems.remove(at: $0) }) else {
            return nil
        }
        let alwaysHiddenControlItem = otherItems.firstIndex(matching: .alwaysHiddenControlItem).map { otherItems.remove(at: $0) }

        self.hiddenControlItem = hiddenControlItem
        self.visibleControlItem = visibleControlItem
        self.alwaysHiddenControlItem = alwaysHiddenControlItem
        self.otherItems = otherItems
    }

    func makeCache(restoring contexts: [MenuBarItemManager.TempShownItemContext]) -> CacheBuildResult {
        let temporaryReturnDestinations = contexts.reduce(into: [:]) { result, context in
            result[context.info] = context.returnDestination
        }

        var cache = MenuBarItemManager.ItemCache()
        var temporaryItems = [(MenuBarItem, MenuBarItemManager.MoveDestination)]()
        var uncachedItems = [MenuBarItem]()

        for item in otherItems {
            if let returnDestination = temporaryReturnDestinations[item.info] {
                temporaryItems.append((item, returnDestination))
            } else if let sectionName = topology.sectionName(for: item.frame) {
                cache[sectionName].append(item)
            } else {
                uncachedItems.append(item)
            }
        }

        for (item, returnDestination) in temporaryItems {
            cache.insert(item, returningTo: returnDestination)
        }

        return CacheBuildResult(cache: cache, uncachedItems: uncachedItems)
    }
}

private struct SectionTopology {
    let visibleControlItemFrame: CGRect
    let alwaysHiddenControlItemFrame: CGRect?

    func sectionName(for itemFrame: CGRect) -> MenuBarSection.Name? {
        if itemFrame.minX >= visibleControlItemFrame.maxX {
            return nil
        }
        if let alwaysHiddenControlItemFrame {
            if itemFrame.maxX <= visibleControlItemFrame.minX, itemFrame.minX >= alwaysHiddenControlItemFrame.maxX {
                return .hidden
            }
            return itemFrame.maxX <= alwaysHiddenControlItemFrame.minX ? .alwaysHidden : nil
        }
        return itemFrame.maxX <= visibleControlItemFrame.minX ? .hidden : nil
    }
}

private struct CacheBuildResult {
    let cache: MenuBarItemManager.ItemCache
    let uncachedItems: [MenuBarItem]
}


private extension MenuBarItemManager.ItemCache {
    mutating func insert(_ item: MenuBarItem, returningTo destination: MenuBarItemManager.MoveDestination) {
        switch destination {
        case .leftOfItem(let targetItem):
            insert(item, leftOf: targetItem)
        case .rightOfItem(let targetItem):
            insert(item, rightOf: targetItem)
        }
    }

    mutating func insert(_ item: MenuBarItem, leftOf targetItem: MenuBarItem) {
        switch targetItem.info {
        case .iceIcon:
            self[.hidden].append(item)
        case .hiddenControlItem:
            self[.hidden].append(item)
        case .alwaysHiddenControlItem:
            self[.alwaysHidden].append(item)
        default:
            insert(item, adjacentTo: targetItem, offsetFromTarget: 0)
        }
    }

    mutating func insert(_ item: MenuBarItem, rightOf targetItem: MenuBarItem) {
        switch targetItem.info {
        case .iceIcon:
            self[.visible].insert(item, at: 0)
        case .hiddenControlItem:
            self[.hidden].insert(item, at: 0)
        case .alwaysHiddenControlItem:
            self[.hidden].insert(item, at: 0)
        default:
            insert(item, adjacentTo: targetItem, offsetFromTarget: -1)
        }
    }

    mutating func insert(_ item: MenuBarItem, adjacentTo targetItem: MenuBarItem, offsetFromTarget: Int) {
        guard
            let targetLocation = firstLocation(matching: targetItem.info)
        else {
            return
        }
        let section = targetLocation.section
        let targetIndex = targetLocation.index

        let insertionIndex = (targetIndex + offsetFromTarget)
            .clamped(to: self[section].startIndex...self[section].endIndex)
        self[section].insert(item, at: insertionIndex)
    }

    private func firstLocation(matching info: MenuBarItemInfo) -> (section: MenuBarSection.Name, index: Int)? {
        for section in MenuBarSection.Name.allCases {
            guard let index = self[section].firstIndex(matching: info) else {
                continue
            }
            return (section, index)
        }
        return nil
    }
}
