//
//  ModelConfigView.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/11.
//

import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
public final class ModelConfigViewModel {
    let store = UserLLMConfigStore.shared

    // 日程提取模型
    var selectedModelName: String {
        didSet {
            if let model = allModels.first(where: { $0.name == selectedModelName }) {
                selectedProviderID = model.providerID ?? ""
            }
            AppSettings.shared.selectedModelName = selectedModelName
        }
    }
    var selectedProviderID: String {
        didSet {
            AppSettings.shared.selectedProviderID = selectedProviderID
        }
    }

    // 连通性测试
    var testResults: [String: ConnectionTestResult] = [:]
    var isTesting = false

    // MARK: - Computed Properties

    var providers: [LLMServiceProvider] {
        SystemLLMConfig.providers + store.userProviders.map { store.toServiceProvider($0) }
    }

    var allModels: [LLMConfiguration] {
        let systemModels = SystemLLMConfig.models
        let userModels = store.userModels.map { store.toModelConfiguration($0) }
        return systemModels + userModels
    }

    init() {
        selectedModelName = AppSettings.shared.selectedModelName
        selectedProviderID = AppSettings.shared.selectedProviderID
    }

    func models(for provider: LLMServiceProvider) -> [LLMConfiguration] {
        allModels.filter { $0.providerID == provider.name }
    }

    private var apiKeys: [String: String] = [:]
    private var keyFieldValues: [String: String] = [:]

    func loadAPIKeys() {
        for provider in providers {
            let savedKey = APIKeyStore.read(for: provider.name)
            apiKeys[provider.name] = savedKey
            keyFieldValues[provider.name] = savedKey ?? ""
        }
    }

    func keyFieldText(for providerID: String) -> String {
        keyFieldValues[providerID] ?? ""
    }

    func setKeyFieldText(_ text: String, for providerID: String) {
        keyFieldValues[providerID] = text
    }

    func hasSavedKey(for providerID: String) -> Bool {
        apiKeys[providerID] != nil
    }

    func saveAPIKey(for providerID: String) {
        let keyText = keyFieldValues[providerID] ?? ""
        let trimmed = keyText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            APIKeyStore.delete(for: providerID)
            apiKeys[providerID] = nil
        } else {
            APIKeyStore.save(for: providerID, value: trimmed)
            apiKeys[providerID] = trimmed
        }
    }

    func selectModel(_ model: LLMConfiguration) {
        selectedModelName = model.name
        if let pid = model.providerID { selectedProviderID = pid }
    }

    var selectedProvider: LLMServiceProvider? {
        providers.first(where: { $0.name == selectedProviderID })
    }

    var currentModel: LLMConfiguration? {
        allModels.first(where: { $0.name == selectedModelName })
    }

    // MARK: - 用户配置管理

    func isUserProvider(_ name: String) -> Bool {
        store.userProviders.contains { $0.name == name }
    }

    func isUserModel(name: String, providerName: String) -> Bool {
        store.userModels.contains { $0.name == name && $0.providerName == providerName }
    }

    /// 删除后检查选中状态，若失效则自动切到第一个可用模型
    func handleSelectionAfterDeletion() {
        guard !allModels.contains(where: { $0.name == selectedModelName }) else { return }
        if let first = allModels.first {
            selectModel(first)
        } else {
            selectedModelName = ""
            selectedProviderID = ""
        }
    }

    func deleteProvider(_ provider: LLMServiceProvider) {
        store.deleteProvider(name: provider.name)
        handleSelectionAfterDeletion()
    }

    // MARK: - 连通性测试

    func testResult(for providerID: String) -> ConnectionTestResult? {
        testResults[providerID]
    }

    func testAllConnections() {
        guard !isTesting else { return }
        isTesting = true
        testResults = [:]

        let providersWithKey = providers.filter { hasSavedKey(for: $0.name) }
        guard !providersWithKey.isEmpty else {
            isTesting = false
            return
        }

        Task {
            await withTaskGroup(of: ConnectionTestResult.self) { group in
                for provider in providersWithKey {
                    let providerModels = models(for: provider)
                    guard let firstModel = providerModels.first,
                          let context = buildRequestContext(for: firstModel, provider: provider) else {
                        let providerID = provider.name
                        group.addTask {
                            .failure(model: "", providerID: providerID, error: "无法构建请求上下文")
                        }
                        continue
                    }
                    group.addTask {
                        await LLMClient.shared.testConnection(context: context, model: firstModel.name, providerID: provider.name)
                    }
                }
                for await result in group {
                    testResults[result.providerID] = result
                }
            }
            isTesting = false
        }
    }

    private func buildRequestContext(for model: LLMConfiguration, provider: LLMServiceProvider) -> LLMRequestContext? {
        guard model.isValidForRequest else { return nil }
        let baseURL = model.resolvedBaseURL(using: provider)
        guard let apiKey = APIKeyStore.read(for: model.providerID ?? model.id.uuidString) else { return nil }
        return LLMRequestContext(baseURL: baseURL, apiKey: apiKey, model: model.name)
    }
}

// MARK: - View

struct ModelConfigView: View {
    @State private var viewModel = ModelConfigViewModel()
    @State private var firstWeekday: Int = AppSettings.shared.firstWeekday
    @State private var showAddLLMConfig = false
    @State private var managingProvider: LLMServiceProvider?
    @State private var providerToDelete: LLMServiceProvider?

    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("日程提取").subtitle()
                HStack {
                    Text("日程提取模型")
                    Spacer(minLength: 200)
                    GroupedPopupSelector(
                        groups: viewModel.providers.map { provider in
                            (title: provider.displayName, items: viewModel.models(for: provider).map { ($0.name, $0.name) })
                        },
                        selectedKey: viewModel.selectedModelName,
                        onSelect: { name in
                            if let model = viewModel.allModels.first(where: { $0.name == name }) {
                                viewModel.selectModel(model)
                            }
                        }
                    )
                }
                
                // 需要确认开关
                HStack {
                    Text("需要确认")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { AppSettings.shared.needsConfirmation },
                        set: { AppSettings.shared.needsConfirmation = $0 }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                }
                
                // 每周起始日
                HStack {
                    Text("每周起始日")
                    Spacer()
                    Picker("", selection: $firstWeekday) {
                        Text("周日").tag(1)
                        Text("周一").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                .onChange(of: firstWeekday) { _, newValue in
                    AppSettings.shared.firstWeekday = newValue
                }
                
                
                Divider()
                    .padding(.vertical, 4)
                
                
                
                HStack {
                    Text("LLM Providers").subtitle()
                    
                    Spacer()
                    
                    Button {
                        showAddLLMConfig = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("添加 LLM 服务商或模型")
                    .sheet(isPresented: $showAddLLMConfig) {
                        AddLLMConfigSheetView()
                    }

                    Button(viewModel.isTesting ? "测试中..." : "测试连通性") {
                        viewModel.testAllConnections()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isTesting)
                }
                
                
                ForEach(viewModel.providers) { provider in
                    ProviderAPIKeyRow(
                        provider: provider,
                        apiKeyText: Binding(
                            get: { viewModel.keyFieldText(for: provider.name) },
                            set: { viewModel.setKeyFieldText($0, for: provider.name) }
                        ),
                        testResult: viewModel.testResult(for: provider.name),
                        onSaveKey: { viewModel.saveAPIKey(for: provider.name) },
                        onManageModels: { managingProvider = provider },
                        onDeleteProvider: { providerToDelete = provider }
                    )
                }

                if viewModel.providers.isEmpty {
                    Text("暂无可用模型配置。")
                        .foregroundColor(.secondary)
                        .padding()
                }




            }
            .padding(20)
        }
        .onAppear {
            viewModel.loadAPIKeys()
        }
        .sheet(item: $managingProvider) { provider in
            ManageModelsSheet(provider: provider, viewModel: viewModel)
        }
        .alert(
            "删除服务商",
            isPresented: Binding(
                get: { providerToDelete != nil },
                set: { if !$0 { providerToDelete = nil } }
            )
        ) {
            Button("删除", role: .destructive) {
                if let provider = providerToDelete {
                    viewModel.deleteProvider(provider)
                    providerToDelete = nil
                }
            }
            Button("取消", role: .cancel) {
                providerToDelete = nil
            }
        } message: {
            if let provider = providerToDelete {
                Text("确定删除服务商「\(provider.displayName)」及其所有模型和 API Key 吗？")
            }
        }
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


// MARK: - Provider API Key Row

struct ProviderAPIKeyRow: View {
    let provider: LLMServiceProvider
    @Binding var apiKeyText: String
    var testResult: ConnectionTestResult?
    let onSaveKey: () -> Void
    var onManageModels: () -> Void = {}
    var onDeleteProvider: () -> Void = {}


    @State private var showKey: Bool = false
    @FocusState private var isKeyFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // MARK: - 可点击 + 右键菜单区域
            HStack(spacing: 8) {
                if let logo = provider.loadLogo() {
                    Image(nsImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "cpu.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                }

                Text(provider.displayName)
                    .font(.body)
                    .frame(width: 80, alignment: .leading)
            }
            .contentShape(Rectangle())      // 确保空白区域也响应手势
            .onTapGesture {
                if let url = provider.apiPlatfromURL {
                    NSWorkspace.shared.open(url)
                }
            }
            .contextMenu {
                Button("管理模型") {
                    onManageModels()
                }
                if let url = provider.apiPlatfromURL {
                    Button("获取 Api Key") {
                        NSWorkspace.shared.open(url)
                    }
                }
                if provider.isUserCustomProvider {
                    Button("删除") {
                        onDeleteProvider()
                    }
                }
                
            }
            .onHover { hovering in
                // 原有的背景动画（保持不变）
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
                // 新增：光标变化（仅当 URL 有效时）
                if provider.apiPlatfromURL != nil {
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.accentColor.opacity(0.12) : Color.clear)
                    .padding(-8)
                    .allowsHitTesting(false)   // 避免挡住右侧按钮 / 输入框的点击
            )
            .help(provider.apiPlatfromURL != nil ? "获取 Api Key" : "")
            

            Spacer()

            // 测试结果圆点
            if let result = testResult {
                Circle()
                    .fill(result.success ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .help(result.success ? "连通 (\(result.latencyMs ?? 0)ms)" : (result.error ?? "连接失败"))
            } else {
                Color.clear
                    .frame(width: 8, height: 8)
            }

            HStack(spacing: 6) {
                Group {
                    if showKey {
                        TextField("输入 API Key", text: $apiKeyText)
                            .textFieldStyle(.roundedBorder)
                            .focused($isKeyFieldFocused)
                            .onChange(of: apiKeyText) { _, _ in
                                onSaveKey()
                            }
                    } else {
                        SecureField("输入 API Key", text: $apiKeyText)
                            .textFieldStyle(.roundedBorder)
                            .focused($isKeyFieldFocused)
                            .onChange(of: apiKeyText) { _, _ in
                                onSaveKey()
                            }
                    }
                }
                .font(.body)

                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(showKey ? "隐藏" : "显示")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add LLM config sheet view

struct AddLLMConfigSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = UserLLMConfigStore.shared
    @State private var showAddProvider = false
    @State private var showAddModel = false

    var allProviders: [LLMServiceProvider] {
        SystemLLMConfig.providers + store.userProviders.map { store.toServiceProvider($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("添加 LLM 配置")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                Button {
                    showAddProvider = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "server.rack")
                            .font(.title2)
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("添加服务商")
                                .font(.body)
                            Text("自定义 API 地址的 LLM 服务商")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    showAddModel = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "cube.box")
                            .font(.title2)
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("添加模型")
                                .font(.body)
                            Text("为已有服务商添加新模型")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(allProviders.isEmpty)
            }
            .padding(20)

            Spacer()
        }
        .frame(width: 400, height: 280)
        .sheet(isPresented: $showAddProvider) {
            AddProviderSheet(store: store)
        }
        .sheet(isPresented: $showAddModel) {
            AddModelSheet(store: store, providers: allProviders)
        }
    }
}

#Preview {
    ModelConfigView()
}
