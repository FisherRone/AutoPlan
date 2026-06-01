//
//  ModelConfigView.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/11.
//

import SwiftUI
import ServiceManagement

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
                
                // 登录时启动
                HStack {
                    Text("登录时启动")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { SMAppService.mainApp.status == .enabled },
                        set: { isEnabled in
                            do {
                                if isEnabled {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                print("Failed to toggle launch at login: \(error)")
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
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
    @State private var showButtons = false

    var body: some View {
        HStack(spacing: 12) {
            //MARK: - 左：logo + 名 + 按钮
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
                
                HStack(spacing: 6) {
                    
                    // 按钮：获取 API Key（若存在 URL）
                    if let url = provider.apiPlatfromURL {
                        Button(action: { NSWorkspace.shared.open(url) }) {
                            Image(systemName: "arrow.up.right")
                                .frame(width: 20, height: 20)
                                
                        }
                        .buttonStyle(.borderless)
                        .hoverShadow()
                        .help("获取 API Key")
                    }
                    
                    // 按钮：管理模型
                    Button(action: onManageModels) {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 20, height: 20)
                            
                    }
                    .buttonStyle(.borderless)
                    .hoverShadow()
                    .help("管理...")
                }
                .frame(width: 50, alignment: .trailing)
                
            }
            .contentShape(.rect)

            Spacer()

            //MARK: - 右：圆点 + Key
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
                    Image(systemName: showKey ? "eye" : "eye.slash")
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
