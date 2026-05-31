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
