//
//  MenuBarItemManager+EventRouting.swift
//  Ice
//

import Cocoa

// MARK: - Event Routing

extension MenuBarItemManager {
    /// Returns a Boolean value that indicates whether the given events have the
    /// same values for each integer value field.
    ///
    /// - Parameters:
    ///   - events: The events to compare.
    ///   - integerFields: An array of integer value fields to compare on each event.
    nonisolated func eventsMatch(_ events: [CGEvent], by integerFields: [CGEventField]) -> Bool {
        var fieldValues = Set<[Int64]>()
        for event in events {
            let values = integerFields.map(event.getIntegerValueField)
            fieldValues.insert(values)
            if fieldValues.count != 1 {
                return false
            }
        }
        return true
    }

    /// Posts an event to the given event tap location.
    ///
    /// - Parameters:
    ///   - event: The event to post.
    ///   - location: The event tap location to post the event to.
    nonisolated func postEvent(_ event: CGEvent, to location: EventTap.Location) {
        Logger.itemManager.debug("Posting \(event.type.logString) to \(location.logString)")
        switch location {
        case .hidEventTap:
            event.post(tap: .cghidEventTap)
        case .sessionEventTap:
            event.post(tap: .cgSessionEventTap)
        case .annotatedSessionEventTap:
            event.post(tap: .cgAnnotatedSessionEventTap)
        case .pid(let pid):
            event.postToPid(pid)
        }
    }

    /// Posts an event to the given event tap location and waits until it is
    /// received before returning.
    ///
    /// - Parameters:
    ///   - event: The event to post.
    ///   - location: The event tap location to post the event to.
    ///   - item: The menu bar item that the event affects.
    func postEventAndWaitToReceive(
        _ event: CGEvent,
        to location: EventTap.Location,
        item: MenuBarItem
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let eventTap = EventTap(
                options: .listenOnly,
                location: location,
                place: .tailAppendEventTap,
                types: [event.type]
            ) { [weak self] proxy, type, rEvent in
                guard let self else {
                    proxy.disable()
                    return nil
                }

                // Reenable the tap if disabled by the system.
                if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                    proxy.enable()
                    return nil
                }

                // Verify that the received event was the sent event.
                guard eventsMatch([rEvent, event], by: CGEventField.menuBarItemEventFields) else {
                    return nil
                }

                // Ensure the tap is enabled, preventing multiple calls to resume().
                guard proxy.isEnabled else {
                    Logger.itemManager.debug("Event tap \"\(proxy.label)\" is disabled (item: \(item.logString))")
                    return nil
                }

                Logger.itemManager.debug("Received \(type.logString) at \(location.logString) (item: \(item.logString))")

                // Disable the tap and resume the continuation.
                proxy.disable()
                continuation.resume()

                return nil
            }

            eventTap.enable(timeout: Timing.eventReceiptTimeout) {
                Logger.itemManager.error("Event tap \"\(eventTap.label)\" timed out (item: \(item.logString))")
                eventTap.disable()
                continuation.resume(throwing: EventError(code: .eventOperationTimeout, item: item))
            }

            // Post the event to the location.
            postEvent(event, to: location)
        }
    }

    /// Routes an event through two tap locations so the target menu bar item receives it.
    ///
    /// - Parameters:
    ///   - event: The event to send.
    ///   - firstLocation: The first location to send the event to.
    ///   - secondLocation: The second location to send the event to.
    ///   - item: The menu bar item that the event affects.
    func routeEventThroughTapBridge(
        _ event: CGEvent,
        from firstLocation: EventTap.Location,
        to secondLocation: EventTap.Location,
        item: MenuBarItem
    ) async throws {
        // Create a null event and assign it unique user data.
        guard let nullEvent = CGEvent(source: nil) else {
            throw EventError(code: .eventCreationFailure, item: item)
        }
        let nullUserData = Int64(truncatingIfNeeded: Int(bitPattern: ObjectIdentifier(nullEvent)))
        nullEvent.setIntegerValueField(.eventSourceUserData, value: nullUserData)

        return try await withCheckedThrowingContinuation { continuation in
            // Create an event tap for the null event at the first location.
            // This tap throws away all events it receives.
            let eventTap1 = EventTap(
                label: "EventTap 1",
                options: .defaultTap,
                location: firstLocation,
                place: .tailAppendEventTap,
                types: [nullEvent.type]
            ) { [weak self] proxy, type, rEvent in
                guard let self else {
                    proxy.disable()
                    return nil
                }

                // Reenable the tap if disabled by the system.
                if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                    proxy.enable()
                    return nil
                }

                // Verify that this is the null event.
                guard rEvent.getIntegerValueField(.eventSourceUserData) == nullUserData else {
                    return nil
                }

                // Disable the tap and post the real event to the second location.
                proxy.disable()
                postEvent(event, to: secondLocation)

                return nil
            }

            // Create an event tap for the real event at the second location.
            // This tap can listen for events, but cannot alter or discard them.
            let eventTap2 = EventTap(
                label: "EventTap 2",
                options: .listenOnly,
                location: secondLocation,
                place: .tailAppendEventTap,
                types: [event.type]
            ) { [weak self] proxy, type, rEvent in
                guard let self else {
                    proxy.disable()
                    return nil
                }

                // Reenable the tap if disabled by the system.
                if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                    proxy.enable()
                    return nil
                }

                // Verify that the received event was the sent event.
                guard eventsMatch([rEvent, event], by: CGEventField.menuBarItemEventFields) else {
                    return nil
                }

                // Ensure the tap is enabled, preventing multiple calls to resume().
                guard proxy.isEnabled else {
                    Logger.itemManager.debug("Event tap \"\(proxy.label)\" is disabled (item: \(item.logString))")
                    return nil
                }

                // Disable the tap, post the event to the first location, and resume
                // the continuation.
                proxy.disable()
                postEvent(event, to: firstLocation)
                continuation.resume()

                return nil
            }

            // Enable both taps, with a timeout on the second tap.
            eventTap1.enable()
            eventTap2.enable(timeout: Timing.eventReceiptTimeout) {
                Logger.itemManager.error("Event tap \"\(eventTap2.label)\" timed out (item: \(item.logString))")
                eventTap1.disable()
                eventTap2.disable()
                continuation.resume(throwing: EventError(code: .eventOperationTimeout, item: item))
            }

            // Post the null event to the first location.
            postEvent(nullEvent, to: firstLocation)
        }
    }

    /// Routes an event to a menu bar item, then waits for the item's frame to change.
    ///
    /// - Parameters:
    ///   - event: The event to send.
    ///   - firstLocation: The first location to send the event to.
    ///   - secondLocation: The second location to send the event to.
    ///   - item: The item whose frame should be observed.
    func routeEventThroughTapBridge(
        _ event: CGEvent,
        from firstLocation: EventTap.Location,
        to secondLocation: EventTap.Location,
        waitingForFrameChangeOf item: MenuBarItem
    ) async throws {
        guard let currentFrame = getCurrentFrame(for: item) else {
            try await routeEventThroughTapBridge(event, from: firstLocation, to: secondLocation, item: item)
            Logger.itemManager.warning("Couldn't get menu bar item frame for \(item.logString), so using fixed delay")
            // This will be slow, but subsequent events will have a better chance of succeeding.
            try await Task.sleep(for: Timing.frameFallbackDelay)
            return
        }
        try await routeEventThroughTapBridge(event, from: firstLocation, to: secondLocation, item: item)
        try await waitForFrameChange(of: item, initialFrame: currentFrame, timeout: Timing.eventReceiptTimeout)
    }

    /// Waits for a menu bar item's frame to change from an initial frame.
    ///
    /// - Parameters:
    ///   - item: The item whose frame should be observed.
    ///   - initialFrame: An initial frame to compare the item's frame against.
    ///   - timeout: The amount of time to wait before throwing a timeout error.
    func waitForFrameChange(of item: MenuBarItem, initialFrame: CGRect, timeout: Duration) async throws {
        struct FrameCheckCancellationError: Error { }

        let frameCheckTask = Task(timeout: timeout) {
            while true {
                try Task.checkCancellation()
                guard let currentFrame = await self.getCurrentFrame(for: item) else {
                    throw FrameCheckCancellationError()
                }
                if currentFrame != initialFrame {
                    Logger.itemManager.debug("Menu bar item frame for \(item.logString) has changed to \(NSStringFromRect(currentFrame))")
                    return
                }
            }
        }
        do {
            try await frameCheckTask.value
        } catch is FrameCheckCancellationError {
            Logger.itemManager.warning("Menu bar item frame check for \(item.logString) was cancelled, so using fixed delay")
            // This will be slow, but subsequent events will have a better chance of succeeding.
            try await Task.sleep(for: Timing.frameFallbackDelay)
        } catch is TaskTimeoutError {
            throw EventError(code: .frameCheckTimeout, item: item)
        }
    }

    /// Permits all events for an event source during the given suppression states,
    /// suppressing local events for the given interval.
    func permitAllEvents(
        for stateID: CGEventSourceStateID,
        during states: [CGEventSuppressionState],
        suppressionInterval: TimeInterval,
        item: MenuBarItem
    ) throws {
        guard let source = CGEventSource(stateID: stateID) else {
            throw EventError(code: .invalidEventSource, item: item)
        }
        for state in states {
            source.setLocalEventsFilterDuringSuppressionState(.permitAllEvents, state: state)
        }
        source.localEventsSuppressionInterval = suppressionInterval
    }

    /// Tries to wake up the given item if it is not responding to events.
    func wakeUpItem(_ item: MenuBarItem) async throws {
        Logger.itemManager.debug("Attempting to wake up \(item.logString)")

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw EventError(code: .invalidEventSource, item: item)
        }
        guard let currentFrame = getCurrentFrame(for: item) else {
            throw EventError(code: .invalidItem, item: item)
        }

        guard
            let mouseDownEvent = CGEvent.menuBarItemEvent(
                type: .move(.leftMouseDown),
                location: CGPoint(x: currentFrame.midX, y: currentFrame.midY),
                item: item,
                pid: item.ownerPID,
                source: source
            ),
            let mouseUpEvent = CGEvent.menuBarItemEvent(
                type: .move(.leftMouseUp),
                location: CGPoint(x: currentFrame.midX, y: currentFrame.midY),
                item: item,
                pid: item.ownerPID,
                source: source
            )
        else {
            throw EventError(code: .eventCreationFailure, item: item)
        }

        try await routeEventThroughTapBridge(
            mouseDownEvent,
            from: .pid(item.ownerPID),
            to: .sessionEventTap,
            item: item
        )
        try await routeEventThroughTapBridge(
            mouseUpEvent,
            from: .pid(item.ownerPID),
            to: .sessionEventTap,
            item: item
        )
    }

}
