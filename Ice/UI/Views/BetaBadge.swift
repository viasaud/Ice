//
//  BetaBadge.swift
//  Ice
//

import SwiftUI

/// A view that displays a badge indicating a beta feature.
struct BetaBadge: View {
    var body: some View {
        TerminalBadge("BETA", tint: .green, fillOpacity: 0.2)
    }
}
