//
//  EventSnippetView.swift
//  AutoPlan
//
//  Interactive Snippet View for Shortcuts.
//

import SwiftUI
import AutoPlanCore
import AppIntents

// MARK: - Preview Snippet View

/// 快捷指令预览卡片：确认前展示
struct EventPreviewSnippetView: View {
    @State var events: [EventItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            
            // Events List
            ForEach(Array(events.enumerated()), id: \.element.id) { index, _ in
                SnippetEventRow(event: events[index], isEditable: true) {
                    events[index].isSelected.toggle()
                }
            }
        }
        .padding()
    }
}

// MARK: - Saved Snippet View

/// 快捷指令结果卡片：保存后展示
struct EventSavedSnippetView: View {
    let events: [EventItem]
    
    private var savedCount: Int { events.filter { $0.status == .saved }.count }
    private var failedCount: Int { events.filter { $0.status != .saved }.count }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("已保存 \(savedCount) 条日程")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            // Events List
            ForEach(events) { event in
                SnippetEventRow(event: event)
            }
            
            // Status（使用固定高度容器避免布局跳变）
            Group {
                if failedCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(failedCount) 条保存失败")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // 固定高度占位，保持布局稳定
                    Color.clear
                        .frame(height: 20)
                }
            }
        }
        .padding()
        .drawingGroup()
    }
}

// MARK: - Event Row

/// 日程行视图，根据类型使用对应的 InfoCard 展示
struct SnippetEventRow: View {
    let event: EventItem
    var isEditable: Bool = false
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧：根据 event.type 分发到对应 InfoCard
            Group {
                switch event.type {
                case .event:
                    EventCard(event: event)
                case .reminder:
                    ReminderCard(event: event)
                case .allDay:
                    AllDayCard(event: event)
                }
            }
            .opacity(event.isSelected ? 1 : 0.4)
            
            // 右侧：红色减号按钮（仅在可编辑模式下显示）
            if isEditable {
                Button {
                    onRemove?()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
