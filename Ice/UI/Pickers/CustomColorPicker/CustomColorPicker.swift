//
//  CustomColorPicker.swift
//  Ice
//

import SwiftUI

struct CustomColorPicker: NSViewRepresentable {
    final class ColorWell: NSColorWell {
        var onActivate: (() -> Void)?

        override func activate(_ exclusive: Bool) {
            onActivate?()
            super.activate(exclusive)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        @Binding var selection: CGColor

        let supportsOpacity: Bool
        let mode: NSColorPanel.Mode

        init(
            selection: Binding<CGColor>,
            supportsOpacity: Bool,
            mode: NSColorPanel.Mode
        ) {
            self._selection = selection
            self.supportsOpacity = supportsOpacity
            self.mode = mode
        }

        func configure(with nsView: ColorWell) {
            nsView.target = self
            nsView.action = #selector(colorChanged(_:))
            nsView.onActivate = { [weak self, weak nsView] in
                guard
                    let self,
                    let nsView
                else {
                    return
                }
                configureColorPanel(for: nsView)
            }
        }

        @objc private func colorChanged(_ sender: NSColorWell) {
            if selection != sender.color.cgColor {
                selection = sender.color.cgColor
            }
        }

        private func configureColorPanel(for nsView: NSColorWell) {
            NSColorPanel.shared.showsAlpha = supportsOpacity
            NSColorPanel.shared.mode = mode
            if let window = nsView.window {
                NSColorPanel.shared.level = window.level + 1
            }
            if NSColorPanel.shared.frame.origin == .zero {
                NSColorPanel.shared.center()
            }
        }
    }

    @Binding var selection: CGColor

    let supportsOpacity: Bool
    let mode: NSColorPanel.Mode

    func makeNSView(context: Context) -> ColorWell {
        let nsView = ColorWell()
        context.coordinator.configure(with: nsView)
        return nsView
    }

    func updateNSView(_ nsView: ColorWell, context: Context) {
        if let color = NSColor(cgColor: selection) {
            nsView.color = color
        }
        nsView.supportsAlpha = supportsOpacity
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selection: $selection,
            supportsOpacity: supportsOpacity,
            mode: mode
        )
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSColorWell,
        context: Context
    ) -> CGSize? {
        switch nsView.controlSize {
        case .extraLarge:
            CGSize(width: 66, height: 36)
        case .large:
            CGSize(width: 55, height: 30)
        case .regular:
            CGSize(width: 44, height: 24)
        case .small:
            CGSize(width: 33, height: 18)
        case .mini:
            CGSize(width: 29, height: 16)
        @unknown default:
            nsView.intrinsicContentSize
        }
    }
}
