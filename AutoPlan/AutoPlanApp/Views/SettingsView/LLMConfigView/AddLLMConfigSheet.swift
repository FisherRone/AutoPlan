//
//  AddLLMConfigSheetView.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/31.
//

import SwiftUI
import SwiftyBeaver
import UniformTypeIdentifiers


extension UTType {
    static var svg: UTType {
        UTType("public.svg-image") ?? .image
    }
}

// MARK: - Warning Enum
enum AddProviderWarning {
    case providerNameTaken
    case urlHasChatCompletions
    case logoSaveFailed
    
    var message: WarningMessage {
        switch self {
        case .providerNameTaken:
            return WarningMessage(
                id: "addProvider.nameTaken",
                severity: .error,
                userText: String(localized: "服务商名称已存在"),
                logText: "AddProvider: provider name already taken"
            )
        case .urlHasChatCompletions:
            return WarningMessage(
                id: "addProvider.urlHasChatCompletions",
                severity: .warning,
                userText: String(localized: "Base URL 中不可以包含 \"/chat/completions\""),
                logText: "AddProvider: baseURL contains /chat/completions"
            )
        case .logoSaveFailed:
            return WarningMessage(
                id: "addProvider.logoSaveFailed",
                severity: .error,
                userText: String(localized: "Logo 保存失败"),
                logText: "AddProvider: logo save failed"
            )
        }
    }
    
    var uiText: Text {
        message.uiNote()
    }
}


// MARK: - Add LLM config sheet view

struct AddLLMConfigSheet: View {
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


// MARK: - Add Provider Sheet

struct AddProviderSheet: View {
    let store: UserLLMConfigStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var displayName = ""
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var apiPlatfromURLString = ""
    @State private var models: [String] = []
    @State private var newModelName = ""
    @State private var selectedLogoURL: URL?
    @State private var showLogoPicker = false
    @State private var showCancelConfirm = false
    @State private var logoSaveWarning: AddProviderWarning?
    @State private var showSaveFailed = false

    private var hasContent: Bool {
        !name.isEmpty || !displayName.isEmpty || !baseURL.isEmpty || !apiKey.isEmpty || !apiPlatfromURLString.isEmpty || !models.isEmpty || selectedLogoURL != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("添加服务商")
                .font(.headline)
                .padding()

            Form {
                Section {
                    TextField("服务商名称", text: $name, prompt: Text("必填"))
                    TextField("Base URL", text: $baseURL, prompt: Text("必填"))
                } header: {
                    Text("服务商信息")
                } footer: {
                    if let error = currentError {
                        error.uiText
                    }
                }

                Section {
                    TextField("服务商别名", text: $displayName)
                    SecureField("API Key", text: $apiKey)
                    TextField("API Key 平台网页链接", text: $apiPlatfromURLString)
                }
                
                HStack {
                    Text("服务商 Logo")
                    Spacer()
                    Button(selectedLogoURL?.lastPathComponent ?? "选择图片") {
                        showLogoPicker = true
                    }
                    if selectedLogoURL != nil {
                        Button("清除") { selectedLogoURL = nil }
                            .foregroundColor(.red)
                    }
                }
                
                if let warning = logoSaveWarning {
                    warning.uiText
                }

                Section("添加模型") {
                    ForEach(Array(models.enumerated()), id: \ .offset) { index, model in
                        HStack {
                            Text(model)
                            Spacer()
                            Button(role: .destructive) {
                                models.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    TextField("", text: $newModelName, prompt: Text("输入模型名称，按回车添加"))
                        .onSubmit {
                            let trimmed = newModelName.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty && !models.contains(trimmed) {
                                models.append(trimmed)
                                newModelName = ""
                            }
                        }
                }

                
            }
            .formStyle(.grouped)

            HStack {
                Button("取消") {
                    if hasContent { showCancelConfirm = true } else { dismiss() }
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 420, height: 520)
        .alert("放弃编辑？", isPresented: $showCancelConfirm) {
            Button("放弃", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("已填写的内容不会被保存。")
        }
        .alert(String(localized: "配置保存失败"), isPresented: $showSaveFailed) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(String(localized: "无法保存服务商配置，请检查磁盘空间或文件权限。"))
        }
        .fileImporter(
            isPresented: $showLogoPicker,
            allowedContentTypes: [.image, .svg],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                selectedLogoURL = url
            }
        }
    }
    
    private var currentError: AddProviderWarning? {
        if !name.isEmpty && store.isProviderNameTaken(name) {
            return .providerNameTaken
        }
        let trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedBase.lowercased().hasSuffix("/chat/completions") {
            return .urlHasChatCompletions
        }
        return nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        currentError != .providerNameTaken
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !store.isProviderNameTaken(trimmedName) else { return }

        // 不填写 DisplayName 时的兜底
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)
        let finalDisplayName = trimmedDisplayName.isEmpty ? trimmedName : trimmedDisplayName

        let provider = UserLLMProvider(
            name: trimmedName,
            displayName: finalDisplayName,
            baseURL: baseURL.trimmingCharacters(in: .whitespaces),
            apiPlatfromURL: apiPlatfromURLString.isEmpty ? nil : URL(string: apiPlatfromURLString)
        )
        
        // 1. 保存 Provider
        store.addProvider(provider)
        
        if store.lastSaveFailed {
            showSaveFailed = true
            return
        }

        // 2. 保存 API Key（可选）
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespaces)
        if !trimmedAPIKey.isEmpty {
            if !APIKeyStore.save(for: trimmedName, value: trimmedAPIKey) {
                showSaveFailed = true
                return
            }
        }

        // 3. 保存模型列表（可选，去重）
        let uniqueModels = Array(Set(models.map { $0.trimmingCharacters(in: .whitespaces) }))
            .filter { !$0.isEmpty }
        for modelName in uniqueModels {
            store.addModel(UserLLMModel(name: modelName, providerName: trimmedName))
        }

        // 4. 保存 Logo
        if let logoURL = selectedLogoURL {
            do {
                try store.saveLogo(for: trimmedName, from: logoURL)
            } catch {
                AddProviderWarning.logoSaveFailed.message.log()
                logoSaveWarning = .logoSaveFailed
            }
        }
        dismiss()
    }
}

// MARK: - Add Model Sheet

struct AddModelSheet: View {
    let store: UserLLMConfigStore
    let providers: [LLMServiceProvider]
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedProviderName: String
    @State private var showCancelConfirm = false
    @State private var isSaving = false

    init(store: UserLLMConfigStore, providers: [LLMServiceProvider]) {
        self.store = store
        self.providers = providers
        _selectedProviderName = State(initialValue: providers.first?.name ?? "")
    }

    private var hasContent: Bool {
        !name.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("添加模型")
                .font(.headline)
                .padding()

            Form {
                TextField("模型名称 (API 请求用)", text: $name)

                Picker("所属服务商", selection: $selectedProviderName) {
                    ForEach(providers) { provider in
                        Text(provider.displayName).tag(provider.name)
                    }
                }
            }
            .formStyle(.grouped)

            if !validationMessage.isEmpty {
                Text(validationMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            HStack {
                Button("取消") {
                    if hasContent { showCancelConfirm = true } else { dismiss() }
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 380, height: 280)
        .alert("放弃编辑？", isPresented: $showCancelConfirm) {
            Button("放弃", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("已填写的内容不会被保存。")
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedProviderName.isEmpty
    }

    private var validationMessage: String {
        guard !isSaving, !name.isEmpty, !selectedProviderName.isEmpty else { return "" }
        if store.isModelNameTaken(name, inProvider: selectedProviderName) {
            return "该服务商下已存在同名模型"
        }
        return ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !store.isModelNameTaken(trimmedName, inProvider: selectedProviderName) else { return }
        isSaving = true
        store.addModel(UserLLMModel(name: trimmedName, providerName: selectedProviderName))
        dismiss()
    }
}



