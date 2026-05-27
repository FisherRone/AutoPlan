//
//  WeeklyReportView.swift
//  AutoPlan
//

import SwiftUI
import AutoPlanCore

@MainActor
@Observable
final class WeeklyReportViewModel {
    var calendarLists: [ListInfo] = []
    var reminderLists: [ListInfo] = []
    var isLoading = false
    var reportDirectoryPath: String = ""
    var directoryAccessError: String?

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let config = try await ListStore.refresh()
            calendarLists = config.userCalendarLists
            reminderLists = config.userReminderLists
        } catch {
            
        }
    }

    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.title = "选择周报保存目录"

        guard panel.runModal() == .OK, let url = panel.urls.first else { return }

        if let bookmarkData = try? url.bookmarkData(options: .withSecurityScope) {
            UserDefaults.standard.set(bookmarkData, forKey: "reportDirectoryBookmark")
        }
        AppSettings.shared.reportDirectory = url.path
        reportDirectoryPath = url.path
    }

    func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: "reportDirectoryBookmark") else { return nil }
        var isStale = false
        guard let resolved = try? URL(resolvingBookmarkData: data,
                                       options: .withSecurityScope,
                                       relativeTo: nil,
                                       bookmarkDataIsStale: &isStale) else { return nil }
        if isStale {
            if let freshData = try? resolved.bookmarkData(options: .withSecurityScope) {
                UserDefaults.standard.set(freshData, forKey: "reportDirectoryBookmark")
            }
        }
        return resolved
    }

    func openDirectory() {
        let path = AppSettings.shared.reportDirectory.isEmpty ? defaultPath : AppSettings.shared.reportDirectory
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    var defaultPath: String {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("AutoPlan", isDirectory: true)
            .appendingPathComponent("Reports", isDirectory: true).path ?? ""
    }
}

struct WeeklyReportView: View {
    @State private var viewModel = WeeklyReportViewModel()
    @State private var focusedEventList: [String] = []
    @State private var focusedReminderList: [String] = []
    @State private var openFailed = false
    @State private var showTemplate = false
    @State private var showPromptVariables = false

    var body: some View {
        VStack(spacing: 0) {

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("提示词").subtitle()
                    // 自定义提示词开关
                    HStack {
                        Text("自定义周报撰写提示词")
                            .font(.body)

                        Button("编辑...") {
                            openWeeklyReportPromptInEditor()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)

                        Button("查看示例") {
                            showTemplate = true
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)

                        Button("占位符说明") {
                            showPromptVariables = true
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { AppSettings.shared.useCustomWeeklyReportPrompt },
                            set: { newValue in
                                if newValue {
                                    PromptBuilder.ensureCustomWeeklyReportPromptFileExists()
                                }
                                AppSettings.shared.useCustomWeeklyReportPrompt = newValue
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                    }
                    .alert("无法打开文件", isPresented: $openFailed) {
                        Button("好", role: .cancel) {}
                    } message: {
                        Text("无法用默认应用打开自定义提示词文件。")
                    }

                    Divider()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading) {
                        Text("关注的列表").subtitle()
                        Text("在周报中，关注的列表将被重点分析和展示。\n你可以在“关注”方框和“不关注”方框之间拖动列表。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 16) {
                        
                        if !viewModel.calendarLists.isEmpty {
                            DualDropListView(
                                title: "日历",
                                icon: "calendar",
                                allItems: viewModel.calendarLists,
                                selectedIDs: $focusedEventList
                            )
                        }

                        if !viewModel.reminderLists.isEmpty {
                            DualDropListView(
                                title: "提醒事项",
                                icon: "checklist",
                                allItems: viewModel.reminderLists,
                                selectedIDs: $focusedReminderList
                            )
                        }
                    }

                    Divider()
                    

                    HStack(spacing: 8) {
                        Text("报告保存路径")
                        
                        let path = AppSettings.shared.reportDirectory.isEmpty ? viewModel.defaultPath : AppSettings.shared.reportDirectory
                        Button(action: {
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        }) {
                            Text(NSString(string: path).abbreviatingWithTildeInPath)
                                .font(.body.monospaced())
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.link)

                        Button("选择…") {
                            viewModel.selectDirectory()
                        }
                        .buttonStyle(.bordered)
                    }

                    if viewModel.calendarLists.isEmpty && viewModel.reminderLists.isEmpty && !viewModel.isLoading {
                        Text("未找到可用列表，请检查日历权限后刷新。")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(20)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showTemplate) {
            TemplatePreviewView(purpose: .weeklyReport)
        }
        .sheet(isPresented: $showPromptVariables) {
            PromptVariablesSheet(purpose: .weeklyReport)
        }
        .task {
            await viewModel.refresh()
            focusedEventList = AppSettings.shared.reportFocusedEventList
            focusedReminderList = AppSettings.shared.reportFocusedReminderList
            viewModel.reportDirectoryPath = AppSettings.shared.reportDirectory
        }
        .onChange(of: focusedEventList) { _, newValue in
            AppSettings.shared.reportFocusedEventList = newValue
        }
        .onChange(of: focusedReminderList) { _, newValue in
            AppSettings.shared.reportFocusedReminderList = newValue
        }
    }

    private var displayPath: String {
        let path = AppSettings.shared.reportDirectory
        return path.isEmpty ? "(默认: \(viewModel.defaultPath))" : path
    }

    private func openWeeklyReportPromptInEditor() {
        PromptBuilder.ensureCustomWeeklyReportPromptFileExists()
        guard let url = PromptBuilder.customWeeklyReportPromptFileURL else {
            openFailed = true
            return
        }
        if !NSWorkspace.shared.open(url) {
            openFailed = true
        }
    }
}

struct DualDropListView: View {
    let title: String
    let icon: String
    let allItems: [ListInfo]
    @Binding var selectedIDs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(alignment: .top, spacing: 8) {
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("关注")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DropTargetView(
                        items: focusedItems,
                        onDrop: { item in
                            guard !selectedIDs.contains(item.id) else { return }
                            selectedIDs.append(item.id)
                        }
                    )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("不关注")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DropTargetView(
                        items: unfocusedItems,
                        onDrop: { item in
                            selectedIDs.removeAll(where: { $0 == item.id })
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var focusedItems: [ListInfo] {
        selectedIDs.compactMap { id in allItems.first(where: { $0.id == id }) }
    }

    private var unfocusedItems: [ListInfo] {
        allItems.filter { !selectedIDs.contains($0.id) }
    }
}

struct DropTargetView: View {
    let items: [ListInfo]
    let onDrop: (ListInfo) -> Void
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                ListItemRow(item: item)
                    .draggable(item)
            }
        }
        .frame(minWidth: 80, minHeight: items.isEmpty ? 44 : nil)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isTargeted ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: ListInfo.self) { droppedItems, _ in
            if let item = droppedItems.first {
                onDrop(item)
            }
            return true
        } isTargeted: { targeting in
            isTargeted = targeting
        }
    }
}

struct ListItemRow: View {
    let item: ListInfo
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: item.colorHex))
                .frame(width: 10, height: 10)

            Text(item.name)
                .font(.callout)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: .windowBackgroundColor)))
    }
}

#Preview {
    WeeklyReportView()
}
