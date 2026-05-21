//
//  MenuBarItemManager+Cache.swift
//  Ice
//

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

        /// Returns the name of the section for the given menu bar item.
        func section(for item: MenuBarItem) -> MenuBarSection.Name? {
            for (section, items) in self.items where items.contains(where: { $0.info == item.info }) {
                return section
            }
            return nil
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
    /// Logs a warning that the given menu bar item was not added to the cache.
    func logNotCachedWarning(for item: MenuBarItem) {
        Logger.itemManager.warning("\(item.logString) was not cached")
    }

    /// Logs a reason for skipping the cache.
    func logSkippingCache(reason: String) {
        Logger.itemManager.debug("Skipping menu bar item cache as \(reason)")
    }

    /// Caches the given menu bar items, without checking whether the control
    /// items are in the correct order.
    func uncheckedCacheItems(
        hiddenControlItem: MenuBarItem,
        alwaysHiddenControlItem: MenuBarItem?,
        otherItems: [MenuBarItem]
    ) {
        Logger.itemManager.debug("Caching menu bar items")

        let classifiedItems = MenuBarSectionLayout.classify(
            items: otherItems,
            hiddenControlItem: hiddenControlItem,
            alwaysHiddenControlItem: alwaysHiddenControlItem
        )

        var cache = ItemCache()
        var tempShownItems = [(MenuBarItem, MoveDestination)]()

        for item in otherItems {
            if let context = tempShownItemContexts.first(where: { $0.info == item.info }) {
                // Keep track of temporarily shown items and their return destinations separately.
                // We want to cache them as if they were in their original locations. Once all other
                // items are cached, use the return destinations to insert the items into the cache
                // at the correct position.
                tempShownItems.append((item, context.returnDestination))
            } else if let sectionName = classifiedItems.first(where: { $0.value.contains(item) })?.key {
                cache[sectionName].append(item)
            } else {
                logNotCachedWarning(for: item)
            }
        }

        for (item, returnDestination) in tempShownItems {
            cache.insert(item, returningTo: returnDestination)
        }

        replaceItemCache(with: cache)
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

        let itemWindowIDs = WindowServerAdapter.windowList(option: [.menuBarItems, .activeSpace])
        if cachedItemWindowIDs == itemWindowIDs {
            logSkippingCache(reason: "item windows have not changed")
            return
        } else {
            cachedItemWindowIDs = itemWindowIDs
        }

        var items = MenuBarItem.getMenuBarItems(onScreenOnly: false, activeSpaceOnly: true)

        let hiddenControlItem = items.firstIndex(matching: .hiddenControlItem).map { items.remove(at: $0) }
        let alwaysHiddenControlItem = items.firstIndex(matching: .alwaysHiddenControlItem).map { items.remove(at: $0) }

        guard let hiddenControlItem else {
            Logger.itemManager.warning("Missing control item for hidden section")
            Logger.itemManager.debug("Clearing menu bar item cache")
            clearItemCache()
            return
        }

        do {
            if let alwaysHiddenControlItem {
                try await enforceControlItemOrder(
                    hiddenControlItem: hiddenControlItem,
                    alwaysHiddenControlItem: alwaysHiddenControlItem
                )
            }
            uncheckedCacheItems(
                hiddenControlItem: hiddenControlItem,
                alwaysHiddenControlItem: alwaysHiddenControlItem,
                otherItems: items
            )
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
    func enforceControlItemOrder(hiddenControlItem: MenuBarItem, alwaysHiddenControlItem: MenuBarItem) async throws {
        guard !isMouseButtonDown else {
            Logger.itemManager.debug("Mouse button is down, so will not enforce control item order")
            return
        }
        guard !mouseHasRecentlyMoved else {
            Logger.itemManager.debug("Mouse has recently moved, so will not enforce control item order")
            return
        }
        if hiddenControlItem.frame.maxX <= alwaysHiddenControlItem.frame.minX {
            Logger.itemManager.info("Arranging menu bar items")
            try await slowMove(item: alwaysHiddenControlItem, to: .leftOfItem(hiddenControlItem))
        }
    }
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
        case .hiddenControlItem:
            self[.visible].insert(item, at: 0)
        case .alwaysHiddenControlItem:
            self[.hidden].insert(item, at: 0)
        default:
            insert(item, adjacentTo: targetItem, offsetFromTarget: -1)
        }
    }

    mutating func insert(_ item: MenuBarItem, adjacentTo targetItem: MenuBarItem, offsetFromTarget: Int) {
        guard
            let section = section(for: targetItem),
            let targetIndex = self[section].firstIndex(matching: targetItem.info)
        else {
            return
        }

        let insertionIndex = (targetIndex + offsetFromTarget)
            .clamped(to: self[section].startIndex...self[section].endIndex)
        self[section].insert(item, at: insertionIndex)
    }
}
