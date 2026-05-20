//
//  LiquidGlassCardStyle.swift
//  Ice
//

import SwiftUI

struct SettingsCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        _VariadicView.Tree(SettingsCardRowsLayout()) {
            content
        }
        .modifier(SettingsCardStyle())
    }
}

private struct SettingsCardStyle: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .background(.thickMaterial)
            .clipShape(shape)
            .overlay {
                shape
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            }
    }
}

private struct SettingsCardRowsLayout: _VariadicView_UnaryViewRoot {
    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id

        VStack(alignment: .leading, spacing: 0) {
            ForEach(children) { child in
                child

                if child.id != last {
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
    }
}

struct TerminalBadge: View {
    let text: String
    let tint: Color
    let fillOpacity: Double

    init(_ text: String, tint: Color, fillOpacity: Double = 0.15) {
        self.text = text
        self.tint = tint
        self.fillOpacity = fillOpacity
    }

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(fillOpacity))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.34), lineWidth: 0.5)
            }
    }
}
