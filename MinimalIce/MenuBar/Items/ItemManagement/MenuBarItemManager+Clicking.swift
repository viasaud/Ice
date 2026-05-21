//
//  MenuBarItemManager+Clicking.swift
//  Ice
//

import Cocoa

// MARK: - Click Items


extension MenuBarItemManager {
    /// Clicks the given menu bar item with the given mouse button.
    func click(item: MenuBarItem, with mouseButton: CGMouseButton) async throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw EventError(code: .invalidEventSource, item: item)
        }
        guard let cursorLocation = MouseCursor.locationCoreGraphics else {
            throw EventError(code: .invalidCursorLocation, item: item)
        }
        guard let currentFrame = getCurrentFrame(for: item) else {
            throw EventError(code: .invalidItem, item: item)
        }

        let buttonStates = mouseButton.buttonStates
        let clickPoint = CGPoint(x: currentFrame.midX, y: currentFrame.midY)

        guard
            let mouseDownEvent = CGEvent.menuBarItemEvent(
                type: .click(buttonStates.down),
                location: clickPoint,
                item: item,
                pid: item.ownerPID,
                source: source
            ),
            let mouseUpEvent = CGEvent.menuBarItemEvent(
                type: .click(buttonStates.up),
                location: clickPoint,
                item: item,
                pid: item.ownerPID,
                source: source
            ),
            let fallbackEvent = CGEvent.menuBarItemEvent(
                type: .click(buttonStates.up),
                location: clickPoint,
                item: item,
                pid: item.ownerPID,
                source: source
            )
        else {
            throw EventError(code: .eventCreationFailure, item: item)
        }

        try permitAllEvents(
            for: .combinedSessionState,
            during: [
                .eventSuppressionStateRemoteMouseDrag,
                .eventSuppressionStateSuppressionInterval,
            ],
            suppressionInterval: 0,
            item: item
        )

        MouseCursor.hide()

        defer {
            MouseCursor.warp(to: cursorLocation)
            MouseCursor.show()
        }

        do {
            Logger.itemManager.info("Clicking \(item.logString) with \(mouseButton.logString)")
            try await postEventAndWaitToReceive(
                mouseDownEvent,
                to: .sessionEventTap,
                item: item
            )
            try await postEventAndWaitToReceive(
                mouseUpEvent,
                to: .sessionEventTap,
                item: item
            )
        } catch {
            do {
                Logger.itemManager.debug("Posting fallback event for clicking \(item.logString)")
                // Catch this, as we still want to throw the existing error if the fallback fails.
                try await postEventAndWaitToReceive(
                    fallbackEvent,
                    to: .sessionEventTap,
                    item: item
                )
            } catch {
                Logger.itemManager.error("Failed to post fallback event for clicking \(item.logString)")
            }
            throw error
        }
    }
}
