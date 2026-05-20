//
//  TemporaryRevealLifecycle.swift
//  Ice
//

/// Small policy surface for deciding when temporary reveals should rehide.
struct TemporaryRevealLifecycle {
    var isMouseButtonDown: Bool
    var isShowingItemInterface: Bool

    var shouldWaitBeforeRehiding: Bool {
        isMouseButtonDown || isShowingItemInterface
    }
}
