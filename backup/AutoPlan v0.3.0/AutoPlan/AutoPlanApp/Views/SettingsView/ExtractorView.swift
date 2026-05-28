//
//  ExtractorView.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/10.
//

import SwiftUI
import AutoPlanCore
import SymbolPicker

// MARK: - ViewModel

@MainActor
@Observable
final class ExtractorViewModel {
    var calendarLists: [ListInfo] = []
    var reminderLists: [ListInfo] = []
    var isLoading = false
    
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let config = try await ListStore.refresh()
            calendarLists = config.userCalendarLists
            reminderLists = config.userReminderLists
        } catch {
            // 静默失败，保持现有列表
        }
    }
    
    /// 设置列表的忽略状态
    func setNeglected(for list: ListInfo, neglected: Bool) {
        ListStore.updateSettings(for: list.id, neglected: neglected, source: list.source)
        updateLocal(list.id, neglected: neglected)
    }
    
    func updatePrompt(_ list: ListInfo, prompt: String) {
        ListStore.updateSettings(for: list.id, prompt: prompt, source: list.source)
        updateLocal(list.id, prompt: prompt)
    }
    
    func setUserIcon(for list: ListInfo, iconName: String) {
        let keyword = list.name.lowercased()
        ListStore.setUserIcon(keyword: keyword, iconName: iconName)
        updateLocal(list.id, iconName: iconName)
    }
    
    private func updateLocal(_ id: String, prompt: String? = nil, neglected: Bool? = nil, iconName: String? = nil) {
        calendarLists = calendarLists.map { item in
            guard item.id == id else { return item }
            var copy = item
            if let p = prompt { copy.prompt = p.isEmpty ? nil : p }
            if let n = neglected { copy.neglected = n }
            if let i = iconName { copy.iconName = i }
            return copy
        }
        reminderLists = reminderLists.map { item in
            guard item.id == id else { return item }
            var copy = item
            if let p = prompt { copy.prompt = p.isEmpty ? nil : p }
            if let n = neglected { copy.neglected = n }
            if let i = iconName { copy.iconName = i }
            return copy
        }
    }
    
    /// 检测同名列表（不区分大小写）
    func findDuplicates(in lists: [ListInfo]) -> Set<String> {
        var seen: [String: String] = [:]
        var duplicates: Set<String> = []
        for list in lists {
            let key = list.name.lowercased()
            if seen[key] != nil {
                duplicates.insert(list.id)
                duplicates.insert(seen[key]!)
            } else {
                seen[key] = list.id
            }
        }
        return duplicates
    }
}

// MARK: - View

struct ExtractorView: View {
    @State private var viewModel = ExtractorViewModel()
    @State private var iconPickerPresented = false
    @State private var iconPickerTarget: ListInfo?
    @State private var iconPickerSymbol = "star"
    @State private var openFailed = false
    @State private var showTemplate = false
    @State private var showPromptVariables = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("提示词").subtitle()
                // 自定义提示词开关
                HStack {
                    Text("自定义日程提取提示词")
                        .font(.body)

                    Button("编辑...") {
                        openExtractionPromptInEditor()
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
                        get: { AppSettings.shared.useCustomExtractionPrompt },
                        set: { newValue in
                            if newValue {
                                PromptBuilder.ensureCustomPromptFileExists()
                            }
                            AppSettings.shared.useCustomExtractionPrompt = newValue
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
                
                
                Text("工作模式").subtitle()

                // 直接保存开关
                HStack {
                    Text("从菜单栏提取时跳过确认，直接保存")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { AppSettings.shared.directSave },
                        set: { AppSettings.shared.directSave = $0 }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                }

                Divider()
                    .padding(.vertical, 4)

                // 标题栏
                HStack {
                    VStack(alignment: .leading) {
                        Text("列表管理").subtitle()
                        Text("提取日程时将自动使用以下列表进行分类。添加描述有助于让分类更加准确。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    Button(action: { Task { await viewModel.refresh() } }) {
                        ZStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 10, height: 10)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .medium))
                                
                            }
                        }
                        .frame(width: 14, height: 14)
                    }
                    .clipShape(Circle())
                    .disabled(viewModel.isLoading)
                }
                
                
                
                if !viewModel.calendarLists.isEmpty {
                    ListSectionView(
                        title: "日历列表",
                        icon: "calendar",
                        lists: viewModel.calendarLists,
                        duplicates: viewModel.findDuplicates(in: viewModel.calendarLists),
                        onSetNeglected: { viewModel.setNeglected(for: $0, neglected: $1) },
                        onUpdatePrompt: { viewModel.updatePrompt($0, prompt: $1) },
                        onUpdateIcon: { list in
                            iconPickerTarget = list
                            iconPickerSymbol = list.iconName
                            iconPickerPresented = true
                        }
                    )
                }
                
                if !viewModel.reminderLists.isEmpty {
                    ListSectionView(
                        title: "提醒事项列表",
                        icon: "checklist",
                        lists: viewModel.reminderLists,
                        duplicates: viewModel.findDuplicates(in: viewModel.reminderLists),
                        onSetNeglected: { viewModel.setNeglected(for: $0, neglected: $1) },
                        onUpdatePrompt: { viewModel.updatePrompt($0, prompt: $1) },
                        onUpdateIcon: { list in
                            iconPickerTarget = list
                            iconPickerSymbol = list.iconName
                            iconPickerPresented = true
                        }
                    )
                }
                
                if viewModel.calendarLists.isEmpty && viewModel.reminderLists.isEmpty && !viewModel.isLoading {
                    Text("未找到可用列表，请检查日历权限后刷新。")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $iconPickerPresented, onDismiss: {
            guard let target = iconPickerTarget else { return }
            viewModel.setUserIcon(for: target, iconName: iconPickerSymbol)
        }) {
            SymbolPicker(symbol: $iconPickerSymbol)
        }
        .sheet(isPresented: $showTemplate) {
            TemplatePreviewView(purpose: .extraction)
        }
        .sheet(isPresented: $showPromptVariables) {
            PromptVariablesSheet(purpose: .extraction)
        }
        .task {await viewModel.refresh()}
    }

    private func openExtractionPromptInEditor() {
        PromptBuilder.ensureCustomPromptFileExists()
        guard let url = PromptBuilder.customPromptFileURL else {
            openFailed = true
            return
        }
        if !NSWorkspace.shared.open(url) {
            openFailed = true
        }
    }
}

// MARK: - Section View

struct ListSectionView: View {
    let title: String
    let icon: String
    let lists: [ListInfo]
    let duplicates: Set<String>
    let onSetNeglected: (ListInfo, Bool) -> Void
    let onUpdatePrompt: (ListInfo, String) -> Void
    let onUpdateIcon: (ListInfo) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.callout.bold())
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            
            ForEach(lists) { list in
                ListRowView(
                    list: list,
                    isDuplicate: duplicates.contains(list.id),
                    onNeglectedChange: { newNeglected in onSetNeglected(list, newNeglected) },
                    onUpdatePrompt: { onUpdatePrompt(list, $0) },
                    onUpdateIcon: { onUpdateIcon(list) }
                )
            }
        }
    }
}

// MARK: - Row View

struct ListRowView: View {
    let list: ListInfo
    let isDuplicate: Bool
    let onNeglectedChange: (Bool) -> Void
    let onUpdatePrompt: (String) -> Void
    let onUpdateIcon: () -> Void
    
    @State private var promptText: String = ""
    
    var body: some View {
        HStack(spacing: 8) {
            // 图标圆点（InfoCards 风格：彩色圆 + 白色 SF Symbol）
            ZStack {
                Circle()
                    .fill(list.available ? Color(hex: list.colorHex) : Color.gray)
                    .frame(width: 14, height: 14)
                
                Image(systemName: list.iconName)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            }
            .onTapGesture {
                guard list.available else { return }
                onUpdateIcon()
            }
            
            // 列表名
            Text(list.name)
                .font(.callout)
                .foregroundColor(list.available ? .primary : .secondary)
                .strikethrough(!list.available)
                .lineLimit(1)
            
            // 失效标记
            if !list.available {
                Text("已失效")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(4)
            }
            
            // 同名警告
            if isDuplicate && list.available {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                    .help("存在同名列表（不区分大小写），保存时将自动选择其中一个。")
            }
            
            Spacer()
            
            // 描述文本框
            TextField("添加描述…", text: $promptText)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                .frame(width: 180)
                .disabled(!list.available)
                .onAppear {
                    promptText = list.prompt ?? ""
                }
                .onChange(of: list.prompt) { _, newValue in
                    if promptText != (newValue ?? "") {
                        promptText = newValue ?? ""
                    }
                }
                .onSubmit {
                    onUpdatePrompt(promptText)
                }
            
            // 忽略开关：打开 = 不忽略，关闭 = 忽略
            let isOn = Binding<Bool>(
                get: { !list.neglected },                      // 开关打开对应不忽略
                set: { newIsOn in
                    let newNeglected = !newIsOn                // 新开关状态映射到 neglected 值
                    onNeglectedChange(newNeglected)
                }
            )
            Toggle(isOn: isOn) {            }
                .toggleStyle(.switch)
                .controlSize(.small)
                .scaleEffect(0.8)
                .disabled(!list.available)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(list.available ? Color.clear : Color.secondary.opacity(0.05))
        )
    }
}

#Preview {
    ExtractorView()
}
