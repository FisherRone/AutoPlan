//
//  UserProviderManagement.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/30.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var svg: UTType {
        UTType("public.svg-image") ?? .image
    }
}

// MARK: - Add Provider Warning Enum


enum AddProviderWarning {
    case providerNameTaken
    case urlHasChatCompletions

    var uiText: Text {
        switch self {
        case .providerNameTaken:
            return Text("服务商名称已存在")
                .foregroundColor(.red)
                .font(.caption)
        case .urlHasChatCompletions:
            return Text("Base URL 中不可以包含 \"/chat/completions\"")
                .foregroundColor(.orange)
                .font(.caption)
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
        .frame(width: 420, height: 580)
        .alert("放弃编辑？", isPresented: $showCancelConfirm) {
            Button("放弃", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("已填写的内容不会被保存。")
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

        // 2. 保存 API Key（可选）
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespaces)
        if !trimmedAPIKey.isEmpty {
            APIKeyStore.save(for: trimmedName, value: trimmedAPIKey)
        }

        // 3. 保存模型列表（可选，去重）
        let uniqueModels = Array(Set(models.map { $0.trimmingCharacters(in: .whitespaces) }))
            .filter { !$0.isEmpty }
        for modelName in uniqueModels {
            store.addModel(UserLLMModel(name: modelName, providerName: trimmedName))
        }

        // 4. 保存 Logo
        if let logoURL = selectedLogoURL {
            try? store.saveLogo(for: trimmedName, from: logoURL)
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
    @State private var selectedProviderName = ""
    @State private var showCancelConfirm = false

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
            .onAppear {
                if selectedProviderName.isEmpty, let first = providers.first {
                    selectedProviderName = first.name
                }
            }

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
        guard !name.isEmpty, !selectedProviderName.isEmpty else { return "" }
        if store.isModelNameTaken(name, inProvider: selectedProviderName) {
            return "该服务商下已存在同名模型"
        }
        return ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !store.isModelNameTaken(trimmedName, inProvider: selectedProviderName) else { return }
        store.addModel(UserLLMModel(name: trimmedName, providerName: selectedProviderName))
        dismiss()
    }
}

// MARK: - Rename Provider Sheet

struct RenameProviderSheet: View {
    let store: UserLLMConfigStore
    let providerName: String
    let currentDisplayName: String
    @Environment(\.dismiss) private var dismiss

    @State private var newDisplayName = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("重命名服务商")
                .font(.headline)

            TextField("显示名称", text: $newDisplayName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    store.updateProvider(name: providerName, displayName: newDisplayName)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newDisplayName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear { newDisplayName = currentDisplayName }
    }
}

// MARK: - Manage Models Sheet

struct ManageModelsSheet: View {
    let provider: LLMServiceProvider
    let viewModel: ModelConfigViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm: (name: String, providerName: String)?

    var body: some View {
        VStack(spacing: 0) {
            Text("\(provider.displayName) 的模型")
                .font(.headline)
                .padding()

            List {
                let providerModels = viewModel.models(for: provider)
                if providerModels.isEmpty {
                    Text("暂无模型")
                        .foregroundColor(.secondary)
                }
                ForEach(providerModels) { model in
                    HStack {
                        Text(model.name)
                        Spacer()
                        if model.origin == .user {
                            Button(role: .destructive) {
                                showDeleteConfirm = (model.name, provider.name)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 380, height: 350)
        .alert("删除模型",
               isPresented: Binding(
                   get: { showDeleteConfirm != nil },
                   set: { if !$0 { showDeleteConfirm = nil } }
               )
        ) {
            Button("删除", role: .destructive) {
                if let item = showDeleteConfirm {
                    viewModel.store.deleteModel(name: item.name, providerName: item.providerName)
                    viewModel.handleSelectionAfterDeletion()
                    showDeleteConfirm = nil
                }
            }
            Button("取消", role: .cancel) {
                showDeleteConfirm = nil
            }
        } message: {
            if let item = showDeleteConfirm {
                Text("确定删除模型「\(item.name)」吗？")
            }
        }
    }
}
