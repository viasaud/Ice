//
//  MenuBarItemManager+TemporaryReveal.swift
//  Ice
//

import Cocoa

extension MenuBarItemManager {
    /// Context for a temporarily shown menu bar item.
    struct TempShownItemContext {
        /// The information associated with the item.
        let info: MenuBarItemInfo

        /// The destination to return the item to.
        let returnDestination: MoveDestination

        /// The window of the item's shown interface.
        let shownInterfaceWindow: WindowInfo?

        /// A Boolean value that indicates whether the menu bar item's interface is showing.
        var isShowingInterface: Bool {
            guard let currentWindow = shownInterfaceWindow.flatMap({ WindowInfo(windowID: $0.windowID) }) else {
                return false
            }
            return if
                currentWindow.layer != CGWindowLevelForKey(.popUpMenuWindow),
                let owningApplication = currentWindow.owningApplication
            {
                owningApplication.isActive && currentWindow.isOnScreen
            } else {
                currentWindow.isOnScreen
            }
        }
    }
}

// MARK: - Temporarily Show Items


extension MenuBarItemManager {
    private struct TemporaryRevealPlan {
        let returnDestination: MoveDestination
        let targetItem: MenuBarItem
        let initialWindows: [WindowInfo]
    }

    /// Gets the destination to return the given item to after it is temporarily shown.
    private func returnDestination(for item: MenuBarItem, in items: [MenuBarItem]) -> MoveDestination? {
        let info = item.info
        if let index = items.firstIndex(where: { $0.info == info }) {
            if items.indices.contains(index + 1) {
                return .leftOfItem(items[index + 1])
            } else if items.indices.contains(index - 1) {
                return .rightOfItem(items[index - 1])
            }
        }
        return nil
    }

    private func visibleItem(matching item: MenuBarItem) -> MenuBarItem? {
        guard
            let latestItem = MenuBarItem(windowID: item.windowID),
            latestItem.isOnScreen
        else {
            return nil
        }
        return latestItem
    }

    private func clickVisibleItemIfNeeded(_ item: MenuBarItem, shouldClick: Bool, mouseButton: CGMouseButton) {
        guard shouldClick else {
            return
        }
        Task {
            do {
                try await click(item: item, with: mouseButton)
            } catch {
                Logger.itemManager.error("Failed to click already visible \(item.logString) (error: \(error))")
            }
        }
    }

    private func makeTemporaryRevealPlan(
        for item: MenuBarItem,
        on screen: NSScreen,
        applicationMenuFrame: CGRect
    ) -> TemporaryRevealPlan? {
        var items = MenuBarItem.getMenuBarItems(onScreenOnly: false, activeSpaceOnly: true)

        guard let returnDestination = returnDestination(for: item, in: items) else {
            Logger.itemManager.warning("No return destination for \(item.logString)")
            return nil
        }

        // Remove all items up to the hidden control item.
        items.trimPrefix { $0.info != .hiddenControlItem }
        guard !items.isEmpty else {
            Logger.itemManager.warning("Missing control item for hidden section, so not showing \(item.logString)")
            return nil
        }
        // Remove the hidden control item.
        items.removeFirst()
        // Remove all offscreen items.
        items.trimPrefix { !$0.isOnScreen }

        let maxX = if let rightArea = screen.auxiliaryTopRightArea {
            max(rightArea.minX + 20, applicationMenuFrame.maxX)
        } else {
            applicationMenuFrame.maxX
        }

        // Remove items until we have enough room to show this item.
        items.trimPrefix { $0.frame.minX - item.frame.width <= maxX }

        guard let targetItem = items.first else {
            let alert = NSAlert()
            alert.messageText = "Not enough room to show \"\(item.displayName)\""
            alert.runModal()
            return nil
        }

        return TemporaryRevealPlan(
            returnDestination: returnDestination,
            targetItem: targetItem,
            initialWindows: WindowInfo.getOnScreenWindows()
        )
    }

    private func revealTemporarily(
        _ item: MenuBarItem,
        using plan: TemporaryRevealPlan,
        clickWhenFinished: Bool,
        mouseButton: CGMouseButton
    ) async {
        do {
            if clickWhenFinished {
                try await slowMove(item: item, to: .leftOfItem(plan.targetItem))
                try await click(item: item, with: mouseButton)
            } else {
                try await move(item: item, to: .leftOfItem(plan.targetItem))
            }
        } catch {
            let action = clickWhenFinished ? "temporarily show and click" : "temporarily show"
            Logger.itemManager.error("Failed to \(action) \(item.logString) (error: \(error))")
        }
    }

    private func cacheTemporarilyShownItem(_ item: MenuBarItem, using plan: TemporaryRevealPlan) {
        let currentWindows = WindowInfo.getOnScreenWindows()

        let shownInterfaceWindow = currentWindows.first { currentWindow in
            currentWindow.ownerPID == item.ownerPID &&
            !plan.initialWindows.contains { initialWindow in
                currentWindow.windowID == initialWindow.windowID
            }
        }

        let context = TempShownItemContext(
            info: item.info,
            returnDestination: plan.returnDestination,
            shownInterfaceWindow: shownInterfaceWindow
        )
        tempShownItemContexts.append(context)
    }

    /// Schedules a timer for the given interval, attempting to rehide the current
    /// temporarily shown items when the timer fires.
    private func runTempShownItemTimer(for interval: TimeInterval) {
        Logger.itemManager.debug("Running rehide timer for temporarily shown items with interval: \(interval)")
        tempShownItemsTimer?.invalidate()
        tempShownItemsTimer = .scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            Logger.itemManager.debug("Rehide timer fired")
            Task {
                await self.rehideTempShownItems()
            }
        }
    }

    /// Temporarily shows the given item.
    ///
    /// The item is cached alongside a destination that it will be automatically returned
    /// to. If `true` is passed to the `clickWhenFinished` parameter, the item is clicked
    /// once movement is finished.
    ///
    /// - Parameters:
    ///   - item: An item to show.
    ///   - clickWhenFinished: A Boolean value that indicates whether the item should be
    ///     clicked once movement is finished.
    ///   - mouseButton: The mouse button of the click.
    func tempShowItem(_ item: MenuBarItem, clickWhenFinished: Bool, mouseButton: CGMouseButton) {
        if let visibleItem = visibleItem(matching: item) {
            clickVisibleItemIfNeeded(visibleItem, shouldClick: clickWhenFinished, mouseButton: mouseButton)
            return
        }

        guard
            let appState,
            let screen = NSScreen.main,
            let applicationMenuFrame = appState.menuBarManager.getApplicationMenuFrame(for: screen.displayID)
        else {
            Logger.itemManager.warning("No application menu frame, so not showing \(item.logString)")
            return
        }

        Logger.itemManager.info("Temporarily showing \(item.logString)")

        guard let revealPlan = makeTemporaryRevealPlan(
            for: item,
            on: screen,
            applicationMenuFrame: applicationMenuFrame
        ) else {
            return
        }

        Task {
            await revealTemporarily(
                item,
                using: revealPlan,
                clickWhenFinished: clickWhenFinished,
                mouseButton: mouseButton
            )
            try? await Task.sleep(for: .milliseconds(100))
            cacheTemporarilyShownItem(item, using: revealPlan)
            runTempShownItemTimer(for: appState.settingsManager.behavior.rehideInterval)
        }
    }

    /// Rehides all temporarily shown items.
    ///
    /// If an item is currently showing its interface, this method waits for the
    /// interface to close before hiding the items.
    func rehideTempShownItems() async {
        itemMoveCount += 1
        defer {
            itemMoveCount -= 1
        }

        guard !tempShownItemContexts.isEmpty else {
            return
        }

        guard !isMouseButtonDown else {
            Logger.itemManager.debug("Mouse button is down, so waiting to rehide")
            runTempShownItemTimer(for: Timing.rehideRetryInterval)
            return
        }
        guard !tempShownItemContexts.contains(where: { $0.isShowingInterface }) else {
            Logger.itemManager.debug("Menu bar item interface is shown, so waiting to rehide")
            runTempShownItemTimer(for: Timing.rehideRetryInterval)
            return
        }

        Logger.itemManager.info("Rehiding temporarily shown items")

        var failedContexts = [TempShownItemContext]()

        let items = MenuBarItem.getMenuBarItems(onScreenOnly: false, activeSpaceOnly: true)

        MouseCursor.hide()

        defer {
            MouseCursor.show()
        }

        while let context = tempShownItemContexts.popLast() {
            guard let item = items.first(where: { $0.info == context.info }) else {
                continue
            }
            do {
                try await move(item: item, to: context.returnDestination)
            } catch {
                Logger.itemManager.error("Failed to rehide \(item.logString) (error: \(error))")
                failedContexts.append(context)
            }
        }

        if failedContexts.isEmpty {
            tempShownItemsTimer?.invalidate()
            tempShownItemsTimer = nil
        } else {
            tempShownItemContexts = failedContexts
            Logger.itemManager.warning("Some items failed to rehide")
            runTempShownItemTimer(for: Timing.rehideRetryInterval)
        }
    }

    /// Removes a temporarily shown item from the cache.
    ///
    /// This ensures that the item will _not_ be returned to its previous location.
    func removeTempShownItemFromCache(with info: MenuBarItemInfo) {
        tempShownItemContexts.removeAll { $0.info == info }
    }
}
