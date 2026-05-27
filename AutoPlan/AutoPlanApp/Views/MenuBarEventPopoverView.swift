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
