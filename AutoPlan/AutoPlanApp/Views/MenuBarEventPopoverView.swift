import SwiftUI
import AutoPlanCore

// MARK: - Popover Content Mode

enum PopoverMode {
    case preview(events: [EventItem])
    case saved([EventItem])
    case error(String)
    case weeklyReportGenerated(directoryPath: String)
}

// MARK: - Clipboard Extraction Popover

/// 从剪贴板提取日程的弹窗视图（纯展示，pipeline 由调用方处理）
struct MenuBarEventPopoverView: View {
    let mode: PopoverMode
    var onDismiss: () -> Void
    var onSave: (([EventItem]) async -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch mode {
            case .preview(let events):
                previewContent(events: events)
            case .saved(let events):
                EventSavedSnippetView(events: events)
            case .error(let message):
                ErrorSnippetView(message: message)
            case .weeklyReportGenerated(let directoryPath):
                weeklyReportGeneratedContent(directoryPath: directoryPath)
            }
        }
        .frame(minWidth: 290, idealWidth: 340)
        .padding()
    }

    // MARK: - Preview

    private func previewContent(events: [EventItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("找到 \(events.count) 条日程")
                .font(.headline)

            EventPreviewSnippetView(events: events)

            Divider()

            HStack(spacing: 12) {
                Button("取消") { onDismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("保存") {
                    Task { await onSave?(events) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Weekly Report Generated

    private func weeklyReportGeneratedContent(directoryPath: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("周报已生成")
                    .font(.headline)
            }

            Divider()

            Text("周报已保存至：")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(directoryPath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Divider()

            HStack(spacing: 12) {
                Button("打开目录") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: directoryPath))
                    onDismiss()
                }

                Spacer()

                Button("好") { onDismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Preview

#Preview("Popover Preview") {
    let allDayEvent = {
        var e = TempEventItem(
            title: "去交大一日游",
            type: .allDay,
            startTime: "2026-05-28"
        ).toInitialEventItem()
        e.listInfo = ListInfo(id: "preview", name: "个人", colorHex: "#FF9500", available: true, source: .calendar, neglected: false, iconName: "house.fill")
        return e
    }()

    let eventItem = {
        var e = TempEventItem(
            title: "上利息论课程",
            type: .event,
            startTime: "2026-05-29 10:00",
            endTime: "2026-05-29 12:00"
        ).toInitialEventItem()
        e.listInfo = ListInfo(id: "preview", name: "学习", colorHex: "#007AFF", available: true, source: .calendar, neglected: false, iconName: "book.fill")
        return e
    }()

    let reminderItem = {
        var e = TempEventItem(
            title: "准备生日礼物",
            type: .reminder,
            reminderTime: "2026-06-01"
        ).toInitialEventItem()
        e.listInfo = ListInfo(id: "preview", name: "个人", colorHex: "#FF2D55", available: true, source: .reminders, neglected: false, iconName: "heart.fill")
        return e
    }()

    let events = [allDayEvent, eventItem, reminderItem]

    VStack(spacing: 20) {
        MenuBarEventPopoverView(
            mode: .preview(events: events),
            onDismiss: {},
            onSave: { _ in }
        )
        .border(.separator)

        MenuBarEventPopoverView(
            mode: .saved(events.map {
                var e = $0
                e.status = .saved
                return e
            }),
            onDismiss: {}
        )
        .border(.separator)

        MenuBarEventPopoverView(
            mode: .error("LLM 服务连接失败，请检查网络和 API Key 配置。"),
            onDismiss: {}
        )
        .border(.separator)

        MenuBarEventPopoverView(
            mode: .weeklyReportGenerated(directoryPath: "/Users/username/Documents/AutoPlan/周报/2026-05-27"),
            onDismiss: {}
        )
        .border(.separator)
    }
    .padding()
    .frame(width: 400)
}
