//
//  ManageModelsSheet.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/31.
//

import SwiftUI
// MARK: - Manage Models Sheet

struct ManageModelsSheet: View {
    let provider: LLMServiceProvider
    let viewModel: ModelConfigViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm: (name: String, providerName: String)?
    @State private var newModelName = ""
    @State private var addModelWarning: String?
    @State private var suppressOnChange = false
    @State private var renamingModel: RenameTarget?

    struct RenameTarget: Identifiable {
        let name: String
        let providerName: String
        var id: String { "\(providerName)/\(name)" }
    }

    var body: some View {
        VStack(alignment: .leading) {
            
            Text(provider.displayName).title() // 编辑后刷新
                .padding(.bottom, 12)
            
            HStack {
                // logo 一个方形区域，，展示，点击可选择新 logo 文件。
                VStack(alignment: .leading) {
                    // provider name 用户加的 provider 可编辑，否则不可编辑
                    // Base URL
                    // ... （和添加 provider 中页面差不多）
                    // 都要做必要的校验
                }
            }

            Divider().padding(.vertical)
            Text("模型").subtitle()
            
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
                    if let warning = addModelWarning {
                        Text(warning)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)

            HStack {
                Button("删除服务商") {}
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
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
        .sheet(item: $renamingModel) { target in
            RenameModelSheet(
                store: viewModel.store,
                oldName: target.name,
                providerName: target.providerName
            )
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
