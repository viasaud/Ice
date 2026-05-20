//
//  MenuBarSectionLayout.swift
//  Ice
//

import CoreGraphics

/// Classifies menu bar items using Ice control items as section delimiters.
struct MenuBarSectionLayout {
    static func sectionName(
        for itemFrame: CGRect,
        hiddenControlItemFrame: CGRect,
        alwaysHiddenControlItemFrame: CGRect?
    ) -> MenuBarSection.Name? {
        if itemFrame.minX >= hiddenControlItemFrame.maxX {
            return .visible
        }

        if let alwaysHiddenControlItemFrame {
            if
                itemFrame.maxX <= hiddenControlItemFrame.minX,
                itemFrame.minX >= alwaysHiddenControlItemFrame.maxX
            {
                return .hidden
            }

            if itemFrame.maxX <= alwaysHiddenControlItemFrame.minX {
                return .alwaysHidden
            }

            return nil
        }

        if itemFrame.maxX <= hiddenControlItemFrame.minX {
            return .hidden
        }

        return nil
    }

    static func classify(
        items: [MenuBarItem],
        hiddenControlItem: MenuBarItem,
        alwaysHiddenControlItem: MenuBarItem?
    ) -> [MenuBarSection.Name: [MenuBarItem]] {
        var result = [MenuBarSection.Name: [MenuBarItem]]()

        for item in items {
            guard let sectionName = sectionName(
                for: item.frame,
                hiddenControlItemFrame: hiddenControlItem.frame,
                alwaysHiddenControlItemFrame: alwaysHiddenControlItem?.frame
            ) else {
                continue
            }
            result[sectionName, default: []].append(item)
        }

        return result
    }
}
