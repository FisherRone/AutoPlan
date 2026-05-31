//
//  Styles.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/25.
//

import SwiftUI

// MARK: - UI Text Styles
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

// MARK: - UI Warning Styles

// 界面内小字提示
struct WarningNoteStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundStyle(.orange)
    }
}

// 界面内小字提示
struct ErrorNoteStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundStyle(.red)
    }
}

extension View {
    func warningNote() -> some View  {
        modifier(WarningNoteStyle())
    }
    
    func errorNote() -> some View {
        modifier(ErrorNoteStyle())
    }
}

// MARK: - Button Styles
struct HoverHandShadowModifier: ViewModifier {
    @State private var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.black.opacity(0.1) : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension View {
    func hoverHandWithShadow() -> some View {
        self.modifier(HoverHandShadowModifier())
    }
}
