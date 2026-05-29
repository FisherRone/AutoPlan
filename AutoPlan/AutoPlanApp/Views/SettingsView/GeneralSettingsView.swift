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
    let providers: [LLMServiceProvider]
    let models: [LLMConfiguration]

    private var apiKeys: [String: String] = [:]
    private var keyFieldValues: [String: String] = [:]

    // 日程提取模型
    var selectedModelName: String {
        didSet {
            if let model = models.first(where: { $0.name == selectedModelName }) {
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
    var testResults: [String: ConnectionTestResult] = [:]  // key: providerID
    var isTesting = false

    init() {
        providers = SystemLLMConfig.providers
        models = SystemLLMConfig.models
        selectedModelName = AppSettings.shared.selectedModelName
        selectedProviderID = AppSettings.shared.selectedProviderID

        for provider in providers {
            let savedKey = readAPIKey(for: provider.name)
            apiKeys[provider.name] = savedKey
            keyFieldValues[provider.name] = savedKey ?? ""
        }
    }

    func models(for provider: LLMServiceProvider) -> [LLMConfiguration] {
        models.filter { $0.providerID == provider.name }
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
        models.first(where: { $0.name == selectedModelName })
    }
    
    
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
                        group.addTask {
                            .failure(model: "", providerID: provider.name, error: "无法构建请求上下文")
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

    private func readAPIKey(for providerID: String) -> String? {
        APIKeyStore.read(for: providerID)
    }
}

// MARK: - View

struct ModelConfigView: View {
    @State private var viewModel = ModelConfigViewModel()
    @State private var firstWeekday: Int = AppSettings.shared.firstWeekday
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("模型")
                    .subtitle()
                HStack {
                    Text("日程提取模型")
                    Spacer(minLength: 200)
                    GroupedPopupSelector(
                        groups: viewModel.providers.map { provider in
                            (title: provider.displayName, items: viewModel.models(for: provider).map { ($0.name, $0.uiDisplayName) })
                        },
                        selectedKey: viewModel.selectedModelName,
                        onSelect: { name in
                            if let model = viewModel.models.first(where: { $0.name == name }) {
                                viewModel.selectModel(model)
                            }
                        }
                    )
                }
                
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    Text("API Key")
                        .subtitle()
                    Spacer()
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
                        onSaveKey: { viewModel.saveAPIKey(for: provider.name) }
                    )
                }
                
                if viewModel.providers.isEmpty {
                    Text("暂无可用模型配置。")
                        .foregroundColor(.secondary)
                        .padding()
                }

                Divider()
                    .padding(.vertical, 4)

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


            }
            .padding(20)
        }
    }
}

// MARK: - Provider API Key Row

struct ProviderAPIKeyRow: View {
    let provider: LLMServiceProvider
    @Binding var apiKeyText: String
    var testResult: ConnectionTestResult?
    let onSaveKey: () -> Void

    @State private var showKey: Bool = false
    @FocusState private var isKeyFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            

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

#Preview {
    ModelConfigView()
}
