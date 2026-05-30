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

// MARK: - Provider Management Row

struct ProviderManagementRow: View {
    let provider: LLMServiceProvider
    let viewModel: ModelConfigViewModel
    let onManageModels: () -> Void

    @State private var showRename = false
    @State private var showLogoPicker = false
    @State private var showDeleteConfirm = false

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

            Spacer()
        }
        .padding(.vertical, 4)
        .contextMenu {
            if viewModel.isUserProvider(provider.name) {
                Button("重命名") { showRename = true }
                Button("更换 Logo") { showLogoPicker = true }
                Divider()
                Button("删除", role: .destructive) { showDeleteConfirm = true }
                Divider()
            }
            Button("管理模型") { onManageModels() }
        }
        .sheet(isPresented: $showRename) {
            RenameProviderSheet(store: viewModel.store, providerName: provider.name, currentDisplayName: provider.displayName)
        }
        .fileImporter(
            isPresented: $showLogoPicker,
            allowedContentTypes: [.image, .svg],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                try? viewModel.store.saveLogo(for: provider.name, from: url)
            }
        }
        .alert("删除服务商", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                viewModel.store.deleteProvider(name: provider.name)
                viewModel.handleSelectionAfterDeletion()
                viewModel.loadAPIKeys()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定删除「\(provider.displayName)」吗？其所有模型和 API Key 也将被删除。")
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
    @State private var apiPlatfromLink = ""
    @State private var selectedLogoURL: URL?
    @State private var showLogoPicker = false

    var body: some View {
        VStack(spacing: 0) {
            Text("添加服务商")
                .font(.headline)
                .padding()

            Form {
                TextField("标识 (唯一 ID)", text: $name)
                TextField("显示名称", text: $displayName)
                TextField("API 基础地址", text: $baseURL)

                if let warning = urlWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                }

                TextField("API Key 管理页面链接 (可选)", text: $apiPlatfromLink)

                HStack {
                    Text("Logo (可选)")
                    Spacer()
                    Button(selectedLogoURL?.lastPathComponent ?? "选择图片") {
                        showLogoPicker = true
                    }
                    if selectedLogoURL != nil {
                        Button("清除") { selectedLogoURL = nil }
                            .foregroundColor(.red)
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
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 420, height: 440)
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

    private var urlWarning: String? {
        guard !baseURL.isEmpty else { return nil }
        if !baseURL.hasPrefix("https://") && !baseURL.hasPrefix("http://") {
            return "建议以 https:// 开头"
        }
        if baseURL.hasSuffix("/chat/completions") {
            return "系统会自动拼接 /chat/completions，建议只填写基础地址"
        }
        return nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var validationMessage: String {
        if !name.isEmpty && store.isProviderNameTaken(name) {
            return "服务商标识已存在"
        }
        return ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !store.isProviderNameTaken(trimmedName) else { return }

        let provider = UserLLMProvider(
            name: trimmedName,
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            baseURL: baseURL.trimmingCharacters(in: .whitespaces),
            apiPlatfromLink: apiPlatfromLink.isEmpty ? nil : apiPlatfromLink
        )
        store.addProvider(provider)

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

    var body: some View {
        VStack(spacing: 0) {
            Text("添加模型")
                .font(.headline)
                .padding()

            Form {
                TextField("模型名称 (API 请求用)", text: $name)

                Picker("所属服务商", selection: $selectedProviderName) {
                    Text("选择服务商").tag("")
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
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 380, height: 280)
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
