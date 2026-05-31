//
//  ManageModelsSheet.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/31.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftyBeaver

// MARK: - Manage Models Sheet

struct ManageModelsSheet: View {
    let provider: LLMServiceProvider
    let viewModel: ModelConfigViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm: (name: String, providerName: String)?
    @State private var showDeleteProviderConfirm = false
    @State private var newModelName = ""
    @State private var addModelWarning: String?
    @State private var suppressOnChange = false
    @State private var renamingModel: RenameTarget?
    @State private var editedDisplayName: String = ""
    @State private var editedBaseURL: String = ""
    @State private var selectedLogoURL: URL?
    @State private var showLogoPicker = false
    @State private var editBaseURLWarning: AddProviderWarning?

    struct RenameTarget: Identifiable {
        let name: String
        let providerName: String
        var id: String { "\(providerName)/\(name)" }
    }
 
    private var isUserProvider: Bool {
        provider.isUserCustomProvider
    }

    var body: some View {
        VStack(alignment: .leading) {
            
            Text(provider.displayName).title()
                .padding(.bottom, 12)
            
            HStack(alignment: .top, spacing: 16) {
                // Logo 区域
                Group {
                    if let logoURL = selectedLogoURL, let nsImage = NSImage(contentsOf: logoURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                    } else if let logo = provider.loadLogo() {
                        Image(nsImage: logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: "cpu.fill")
                            .font(.title)
                            .foregroundColor(.secondary)
                            .frame(width: 48, height: 48)
                    }
                }
                .frame(width: 60)
                .onTapGesture {
                    guard isUserProvider else { return }
                    showLogoPicker = true
                }
                .help(isUserProvider ? "点击更换 Logo" : "")
                
                // Provider 信息
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("服务商名称")
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .leading)
                        Spacer()
                        if isUserProvider {
                            TextField("", text: $editedDisplayName)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                        } else {
                            Text(provider.displayName)
                                .textSelection(.enabled)
                        }
                    }
                    
                    HStack {
                        Text("Base URL")
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .leading)
                        Spacer()
                        if isUserProvider {
                            TextField("Base URL", text: $editedBaseURL)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                        } else {
                            Text(provider.baseURL)
                                .textSelection(.enabled)
                                .lineLimit(1)
                        }
                    }
                    
                    if let warning = editBaseURLWarning {
                        warning.uiText
                    }

                }
            }

            Divider().padding(.vertical)
            Text("模型").subtitle()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
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
                                Button {
                                    renamingModel = RenameTarget(name: model.name, providerName: provider.name)
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                
                                Button(role: .destructive) {
                                    showDeleteConfirm = (model.name, provider.name)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        TextField("点击添加模型，按回车确认", text: $newModelName)
                            .textFieldStyle(.plain)
                            .onChange(of: newModelName) { _, _ in
                                if suppressOnChange {
                                    suppressOnChange = false
                                } else {
                                    addModelWarning = nil
                                }
                            }
                            .onSubmit {
                                let trimmed = newModelName.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                if viewModel.store.isModelNameTaken(trimmed, inProvider: provider.name) {
                                    addModelWarning = "该服务商下已存在同名模型"
                                    suppressOnChange = true
                                    newModelName = ""
                                    return
                                }
                                viewModel.store.addModel(UserLLMModel(name: trimmed, providerName: provider.name))
                                newModelName = ""
                                addModelWarning = nil
                            }
                        Text(addModelWarning ?? "")
                            .foregroundColor(.red)
                            .font(.caption)
                            .frame(height: addModelWarning != nil ? nil : 0)
                            .opacity(addModelWarning != nil ? 1 : 0)
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollIndicators(.never)

            HStack {
                if isUserProvider {
                    Button("删除服务商", role: .destructive) {
                        showDeleteProviderConfirm = true
                    }
                }
                Spacer()
                Button("完成") {
                    saveProviderChanges()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400, height: 380)
        .onAppear {
            editedDisplayName = provider.displayName
            editedBaseURL = provider.baseURL
        }
        .fileImporter(
            isPresented: $showLogoPicker,
            allowedContentTypes: [.image, .svg],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                selectedLogoURL = url
                saveLogo()
            }
        }
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
        .sheet(item: $renamingModel) { target in
            RenameModelSheet(
                store: viewModel.store,
                oldName: target.name,
                providerName: target.providerName
            )
        }
        .alert(
            "删除服务商",
            isPresented: $showDeleteProviderConfirm
        ) {
            Button("删除", role: .destructive) {
                viewModel.deleteProvider(provider)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定删除服务商「\(provider.displayName)」及其所有模型和 API Key 吗？")
        }
    }
    
    private func saveProviderChanges() {
        guard isUserProvider else { return }
        let trimmedName = editedDisplayName.trimmingCharacters(in: .whitespaces)
        let trimmedURL = editedBaseURL.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedURL.isEmpty else { return }
        
        let trimmedBase = trimmedURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedBase.lowercased().hasSuffix("/chat/completions") {
            editBaseURLWarning = .urlHasChatCompletions
            return
        }
        editBaseURLWarning = nil
        
        viewModel.store.updateProvider(
            name: provider.name,
            displayName: trimmedName,
            baseURL: trimmedURL
        )
    }
    
    private func saveLogo() {
        guard isUserProvider, let logoURL = selectedLogoURL else { return }
        do {
            try viewModel.store.saveLogo(for: provider.name, from: logoURL)
        } catch {
            logger.error("Logo 保存失败: \(error)")
        }
    }
}

// MARK: - Rename Model Sheet

struct RenameModelSheet: View {
    let store: UserLLMConfigStore
    let oldName: String
    let providerName: String
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("重命名模型")
                .font(.headline)

            TextField("模型名称", text: $newName)
                .textFieldStyle(.roundedBorder)

            if !validationMessage.isEmpty {
                Text(validationMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    store.renameModel(oldName: oldName, providerName: providerName, newName: newName.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear { newName = oldName }
    }

    private var isValid: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed != oldName && validationMessage.isEmpty
    }

    private var validationMessage: String {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != oldName else { return "" }
        if store.isModelNameTaken(trimmed, inProvider: providerName) {
            return "该服务商下已存在同名模型"
        }
        return ""
    }
}
