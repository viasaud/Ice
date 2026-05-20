//
//  ReadWindow.swift
//  Ice
//

import SwiftUI

private struct WindowReader: NSViewRepresentable {
    final class WindowObservingView: NSView {
        var onWindowChange: @MainActor (NSWindow?) -> Void = { _ in }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange(window)
        }
    }

    let onWindowChange: @MainActor (NSWindow?) -> Void

    func makeNSView(context: Context) -> WindowObservingView {
        let view = WindowObservingView()
        view.onWindowChange = onWindowChange
        return view
    }

    func updateNSView(_ nsView: WindowObservingView, context: Context) {
        nsView.onWindowChange = onWindowChange
    }
}

extension View {
    /// Reads the window of this view, performing the given closure when
    /// the window changes.
    ///
    /// - Parameter onChange: A closure to perform when the window changes.
    func readWindow(onChange: @MainActor @escaping (_ window: NSWindow?) -> Void) -> some View {
        background {
            WindowReader(onWindowChange: onChange)
        }
    }

    /// Reads the window of this view, assigning it to the given binding.
    ///
    /// - Parameter window: A binding to use to store the view's window.
    func readWindow(window: Binding<NSWindow?>) -> some View {
        readWindow { window.wrappedValue = $0 }
    }
}
