//
//  ScreenCapture.swift
//  Ice
//

import CoreGraphics
import ScreenCaptureKit

/// A namespace for screen capture operations.
enum ScreenCapture {
    /// Returns a Boolean value that indicates whether the app has been granted screen capture permissions.
    static func checkPermissions() -> Bool {
        for item in MenuBarItem.getMenuBarItems(onScreenOnly: false, activeSpaceOnly: true) {
            // Don't check items owned by Ice.
            if item.owningApplication == .current {
                continue
            }
            return item.title != nil
        }
        // CGPreflightScreenCaptureAccess() only returns an initial value for whether the app
        // has permissions, but we can use it as a fallback.
        return CGPreflightScreenCaptureAccess()
    }

    /// Returns a Boolean value that indicates whether the app has been granted screen capture permissions.
    ///
    /// The first time this function is called, the permissions state is computed, cached, and returned.
    /// Subsequent calls either return the cached value, or recompute the permissions state before caching
    /// and returning it.
    static func cachedCheckPermissions(reset: Bool = false) -> Bool {
        enum Context {
            nonisolated(unsafe) static var lastCheckResult: Bool?
        }

        if !reset {
            if let lastCheckResult = Context.lastCheckResult {
                return lastCheckResult
            }
        }

        let realResult = checkPermissions()
        Context.lastCheckResult = realResult
        return realResult
    }

    /// Requests screen capture permissions.
    static func requestPermissions() {
        if #available(macOS 15.0, *) {
            // CGRequestScreenCaptureAccess() is broken on macOS 15. SCShareableContent requires
            // screen capture permissions, and triggers a request if the user doesn't have them.
            SCShareableContent.getWithCompletionHandler { _, _ in }
        } else {
            CGRequestScreenCaptureAccess()
        }
    }

    /// Captures a composite image of an array of windows.
    ///
    /// - Parameters:
    ///   - windowIDs: The identifiers of the windows to capture.
    ///   - screenBounds: The bounds to capture. Pass `nil` to capture the minimum rectangle that encloses the windows.
    ///   - option: Options that specify the image to be captured.
    static func captureWindows(_ windowIDs: [CGWindowID], screenBounds: CGRect? = nil, option: CGWindowImageOption = []) -> CGImage? {
        guard !windowIDs.isEmpty else {
            return nil
        }

        let captureResult = CaptureResult()
        let semaphore = DispatchSemaphore(value: 0)
        let finish: @Sendable () -> Void = {
            semaphore.signal()
        }

        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
            guard
                error == nil,
                let content
            else {
                finish()
                return
            }

            let windows = content.windows.filter { windowIDs.contains($0.windowID) }
            guard
                !windows.isEmpty,
                let display = display(for: screenBounds, windows: windows, in: content.displays)
            else {
                finish()
                return
            }

            let filter = SCContentFilter(display: display, including: windows)
            let configuration = SCScreenshotConfiguration()
            configuration.showsCursor = false
            configuration.dynamicRange = .sdr
            configuration.ignoreShadows = option.contains(.boundsIgnoreFraming)
            if let screenBounds {
                configuration.sourceRect = screenBounds
            }

            SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration) { output, error in
                defer {
                    finish()
                }
                guard error == nil else {
                    return
                }
                captureResult.image = output?.sdrImage
            }
        }

        semaphore.wait()
        return captureResult.image
    }

    /// Captures an image of a window.
    ///
    /// - Parameters:
    ///   - windowID: The identifier of the window to capture.
    ///   - screenBounds: The bounds to capture. Pass `nil` to capture the minimum rectangle that encloses the window.
    ///   - option: Options that specify the image to be captured.
    static func captureWindow(_ windowID: CGWindowID, screenBounds: CGRect? = nil, option: CGWindowImageOption = []) -> CGImage? {
        captureWindows([windowID], screenBounds: screenBounds, option: option)
    }

    /// Returns the display that best contains the requested capture.
    private static func display(for screenBounds: CGRect?, windows: [SCWindow], in displays: [SCDisplay]) -> SCDisplay? {
        if let screenBounds {
            return displays.first { $0.frame.intersects(screenBounds) }
        }

        guard let windowFrame = windows.first?.frame else {
            return displays.first
        }

        return displays.first { $0.frame.intersects(windowFrame) } ?? displays.first
    }
}

private final class CaptureResult: @unchecked Sendable {
    var image: CGImage?
}
