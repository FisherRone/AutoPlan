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
    @State private var editingModelID: UUID?
    @State private var editingName = ""
    @FocusState private var focusedModelID: UUID?

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
                        if editingModelID == model.id {
                            TextField("模型名称", text: $editingName)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedModelID, equals: model.id)
                                .onSubmit {
                                    saveRename(model: model)
                                }
                                .onChange(of: focusedModelID) { _, newValue in
                                    if newValue != model.id && editingModelID == model.id {
                                        saveRename(model: model)
                                    }
                                }
                            
                            Spacer()
                        } else {
                            Button {
                                if model.origin == .user {
                                    startEditing(model: model)
                                }
                            } label: {
                                HStack {
                                    Text(model.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if model.origin == .user {
                                    Button {
                                        startEditing(model: model)
                                    } label: {
                                        Label("重命名", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        showDeleteConfirm = (model.name, provider.name)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                            
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
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.secondary)
                    TextField("添加模型，按回车确认", text: $newModelName)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            let trimmed = newModelName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            guard !viewModel.store.isModelNameTaken(trimmed, inProvider: provider.name) else { return }
                            viewModel.store.addModel(UserLLMModel(name: trimmed, providerName: provider.name))
                            newModelName = ""
                        }
                }
                .padding(.vertical, 4)
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
    
    private func startEditing(model: LLMConfiguration) {
        editingModelID = model.id
        editingName = model.name
        focusedModelID = model.id
    }
    
    private func saveRename(model: LLMConfiguration) {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty {
            editingModelID = nil
            return
        }
        
        if viewModel.store.isModelNameTaken(trimmed, inProvider: provider.name) {
            editingModelID = nil
            return
        }
        
        viewModel.store.renameModel(oldName: model.name, providerName: provider.name, newName: trimmed)
        editingModelID = nil
    }
}
