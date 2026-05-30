//
//  Styles.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/25.
//

import SwiftUI

struct PageTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title2.bold())
    }
}

struct PageSubtitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body.bold())
    }
}

struct PageFootnoteStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}


extension View {
    func title() -> some View  {
        modifier(PageTitleStyle())
    }
    
    func subtitle() -> some View {
        modifier(PageSubtitleStyle())
    }
    
    func note() -> some View {
        modifier(PageFootnoteStyle())
    }
}

// MARK: - Grouped Popup Selector (NSPopUpButton)

struct GroupedPopupSelector: NSViewRepresentable {
    let groups: [(title: String, items: [(key: String, label: String)])]
    let selectedKey: String
    let onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.target = context.coordinator
        popup.action = #selector(Coordinator.selectionChanged(_:))
        popup.focusRingType = .none
        popup.autoenablesItems = false
        rebuildMenu(popup, coordinator: context.coordinator)
        return popup
    }

    func updateNSView(_ popup: NSPopUpButton, context: Context) {
        rebuildMenu(popup, coordinator: context.coordinator)
    }

    private func rebuildMenu(_ popup: NSPopUpButton, coordinator: Coordinator) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        var selectedItem: NSMenuItem?
        var firstValidItem: NSMenuItem?

        for group in groups where !group.items.isEmpty {
            let sectionItem = NSMenuItem(title: group.title, action: nil, keyEquivalent: "")
            sectionItem.isEnabled = false
            menu.addItem(sectionItem)

            for entry in group.items {
                let item = NSMenuItem(title: entry.label, action: nil, keyEquivalent: "")
                item.representedObject = entry.key
                item.isEnabled = true
                menu.addItem(item)

                if firstValidItem == nil {
                    firstValidItem = item
                }

                if entry.key == selectedKey {
                    selectedItem = item
                }
            }

            menu.addItem(.separator())
        }

        popup.menu = menu

        if let selected = selectedItem {
            popup.select(selected)
        } else if let first = firstValidItem {
            popup.select(first)
        }
    }

    class Coordinator: NSObject {
        let onSelect: (String) -> Void

        init(onSelect: @escaping (String) -> Void) {
            self.onSelect = onSelect
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            guard let item = sender.selectedItem,
                  let key = item.representedObject as? String else { return }
            onSelect(key)
        }
    }
}
