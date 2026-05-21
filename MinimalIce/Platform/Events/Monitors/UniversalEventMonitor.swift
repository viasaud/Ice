import Cocoa
import Combine

private protocol EventMonitoring: AnyObject {
    func start()
    func stop()
}

final class UniversalEventMonitor: EventMonitoring {
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> NSEvent?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        guard localMonitor == nil, globalMonitor == nil else {
            return
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [handler] event in
            _ = handler(event)
        }
    }

    func stop() {
        [localMonitor, globalMonitor].compactMap { $0 }.forEach(NSEvent.removeMonitor)
        localMonitor = nil
        globalMonitor = nil
    }

    static func publisher(for mask: NSEvent.EventTypeMask) -> EventPublisher {
        EventPublisher { receive in
            UniversalEventMonitor(mask: mask) { event in
                receive(event)
                return event
            }
        }
    }
}

final class RunLoopLocalEventMonitor: EventMonitoring {
    private let runLoop = CFRunLoopGetCurrent()
    private let mode: RunLoop.Mode
    private let observer: CFRunLoopObserver

    init(
        mask: NSEvent.EventTypeMask,
        mode: RunLoop.Mode,
        handler: @MainActor @escaping (NSEvent) -> NSEvent?
    ) {
        self.mode = mode
        self.observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            CFRunLoopActivity.beforeSources.rawValue,
            true,
            0
        ) { _, _ in
            MainActor.assumeIsolated {
                var events = [NSEvent]()
                while let event = NSApp.nextEvent(matching: .any, until: nil, inMode: .default, dequeue: true) {
                    events.append(event)
                }
                for event in events {
                    if !mask.contains(NSEvent.EventTypeMask(rawValue: 1 << event.type.rawValue)) {
                        NSApp.postEvent(event, atStart: false)
                    } else if let handledEvent = handler(event) {
                        NSApp.postEvent(handledEvent, atStart: false)
                    }
                }
            }
        }
    }

    deinit {
        stop()
    }

    func start() {
        CFRunLoopAddObserver(runLoop, observer, CFRunLoopMode(mode.rawValue as CFString))
    }

    func stop() {
        CFRunLoopRemoveObserver(runLoop, observer, CFRunLoopMode(mode.rawValue as CFString))
    }

    static func publisher(for mask: NSEvent.EventTypeMask, mode: RunLoop.Mode) -> EventPublisher {
        EventPublisher { receive in
            nonisolated(unsafe) let unsafeReceive = receive
            return RunLoopLocalEventMonitor(mask: mask, mode: mode) { event in
                unsafeReceive(event)
                return event
            }
        }
    }
}

struct EventPublisher: Publisher {
    typealias Output = NSEvent
    typealias Failure = Never

    fileprivate let makeMonitor: (@escaping (NSEvent) -> Void) -> EventMonitoring

    func receive<S: Subscriber<Output, Failure>>(subscriber: S) {
        subscriber.receive(subscription: EventSubscription(subscriber: subscriber, makeMonitor: makeMonitor))
    }
}

private final class EventSubscription<S: Subscriber<NSEvent, Never>>: Subscription {
    private var subscriber: S?
    private let monitor: EventMonitoring

    init(subscriber: S, makeMonitor: (@escaping (NSEvent) -> Void) -> EventMonitoring) {
        self.subscriber = subscriber
        self.monitor = makeMonitor { event in
            _ = subscriber.receive(event)
        }
        monitor.start()
    }

    func request(_ demand: Subscribers.Demand) { }

    func cancel() {
        monitor.stop()
        subscriber = nil
    }
}
