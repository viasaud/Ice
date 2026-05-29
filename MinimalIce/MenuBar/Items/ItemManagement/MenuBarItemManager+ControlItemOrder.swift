import CoreGraphics

extension MenuBarItemManager {
    /// Logs a reason for skipping the control item order check.
    private func logSkippingOrderCheck(reason: String) {
        Logger.itemManager.debug("Skipping control item order check as \(reason)")
    }

    /// Ensures that the always-hidden control item stays to the left of the hidden
    /// control item.
    func repairControlItemOrderIfNeeded() async {
        do {
            try await waitForItemsToStopMoving(timeout: .seconds(1))
        } catch is TaskTimeoutError {
            logSkippingOrderCheck(reason: "an item is currently being moved")
            return
        } catch {
            guard !itemHasRecentlyMoved else {
                logSkippingOrderCheck(reason: "an item was recently moved")
                return
            }
        }

        let itemWindowIDs = WindowServerAdapter.activeSpaceMenuBarItemWindowIDs
        if lastObservedMenuBarItemWindowIDs == itemWindowIDs {
            logSkippingOrderCheck(reason: "item windows have not changed")
            return
        } else {
            lastObservedMenuBarItemWindowIDs = itemWindowIDs
        }

        guard let snapshot = ObservedMenuBarSnapshot(items: MenuBarItem.getMenuBarItems(onScreenOnly: false, activeSpaceOnly: true)) else {
            Logger.itemManager.warning("Missing control item for hidden section")
            return
        }

        do {
            try await enforceControlItemOrderIfNeeded(in: snapshot)
        } catch {
            Logger.itemManager.error("Error enforcing control item order: \(error)")
        }
    }
}

extension MenuBarItemManager {
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
    let alwaysHiddenControlItem: MenuBarItem?

    var needsControlItemOrderRepair: Bool {
        guard let alwaysHiddenControlItem else {
            return false
        }
        return hiddenControlItem.frame.maxX <= alwaysHiddenControlItem.frame.minX
    }

    init?(items: [MenuBarItem]) {
        var hiddenControlItem: MenuBarItem?
        var alwaysHiddenControlItem: MenuBarItem?

        for item in items {
            switch item.info {
            case .hiddenControlItem where hiddenControlItem == nil:
                hiddenControlItem = item
            case .alwaysHiddenControlItem where alwaysHiddenControlItem == nil:
                alwaysHiddenControlItem = item
            default:
                break
            }
        }

        guard let hiddenControlItem else {
            return nil
        }

        self.hiddenControlItem = hiddenControlItem
        self.alwaysHiddenControlItem = alwaysHiddenControlItem
    }
}
