//
//  UserLLMConfigStore.swift
//  AutoPlanCore
//
//  Created by 荣子鱼 on 2026/5/30.
//

import Foundation
import Observation
#if os(macOS)
import AppKit
#endif

// MARK: - Data Models

/// 用户自定义服务商（JSON 持久化结构）
public struct UserLLMProvider: Codable, Identifiable, Equatable {
    public var name: String           // 唯一标识
    public var displayName: String    // 显示名称
    public var baseURL: String        // API 基础地址
    public var apiPlatfromLink: String? // API Key 管理页面链接

    public var id: String { name }

    public init(name: String, displayName: String, baseURL: String, apiPlatfromLink: String? = nil) {
        self.name = name
        self.displayName = displayName
        self.baseURL = baseURL
        self.apiPlatfromLink = apiPlatfromLink
    }
}

/// 用户自定义模型（JSON 持久化结构）
public struct UserLLMModel: Codable, Equatable {
    public var name: String           // 模型名称（API 请求用）
    public var providerName: String   // 所属服务商标识

    public init(name: String, providerName: String) {
        self.name = name
        self.providerName = providerName
    }
}

/// JSON 文件根结构
struct UserLLMConfigData: Codable {
    var userLLMProviders: [UserLLMProvider]
    var userModels: [UserLLMModel]

    enum CodingKeys: String, CodingKey {
        case userLLMProviders = "UserLLMProviders"
        case userModels = "UserModels"
    }
}

// MARK: - Store

/// 用户自定义 LLM 配置的持久化存储与 CRUD 管理
/// JSON 存储在 `~/Library/Application Support/AutoPlan/user_providers_v1.json`
/// Logo 文件存储在同目录下的 `logos/` 子目录
@MainActor
@Observable
public final class UserLLMConfigStore {
    public static let shared = UserLLMConfigStore()

    private(set) public var userProviders: [UserLLMProvider] = []
    private(set) public var userModels: [UserLLMModel] = []

    private let fileName = "user_providers_v1.json"

    private var fileURL: URL {
        Self.appSupportDir.appendingPathComponent(fileName)
    }

    private var logoDir: URL {
        Self.appSupportDir.appendingPathComponent("logos")
    }

    static var appSupportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("AutoPlan")
    }

    private init() {
        ensureDirectoryExists()
        load()
    }

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: Self.appSupportDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: logoDir, withIntermediateDirectories: true)
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let config = try JSONDecoder().decode(UserLLMConfigData.self, from: data)
            userProviders = config.userLLMProviders
            userModels = config.userModels
        } catch {
            // 文件损坏或格式不兼容，保留空数据
        }
    }

    private func save() {
        let config = UserLLMConfigData(userLLMProviders: userProviders, userModels: userModels)
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // 保存失败
        }
    }

    // MARK: - Provider CRUD

    public func addProvider(_ provider: UserLLMProvider) {
        userProviders.append(provider)
        save()
    }

    public func updateProvider(name: String, displayName: String? = nil, baseURL: String? = nil, apiPlatfromLink: String? = nil) {
        guard let idx = userProviders.firstIndex(where: { $0.name == name }) else { return }
        if let displayName { userProviders[idx].displayName = displayName }
        if let baseURL { userProviders[idx].baseURL = baseURL }
        if let apiPlatfromLink { userProviders[idx].apiPlatfromLink = apiPlatfromLink }
        save()
    }

    public func deleteProvider(name: String) {
        userProviders.removeAll { $0.name == name }
        userModels.removeAll { $0.providerName == name }
        deleteLogo(for: name)
        APIKeyStore.delete(for: name)
        save()
    }

    // MARK: - Model CRUD

    public func addModel(_ model: UserLLMModel) {
        userModels.append(model)
        save()
    }

    public func deleteModel(name: String, providerName: String) {
        userModels.removeAll { $0.name == name && $0.providerName == providerName }
        save()
    }

    public func deleteModels(forProvider providerName: String) {
        userModels.removeAll { $0.providerName == providerName }
        save()
    }

    // MARK: - Validation

    public func isProviderNameTaken(_ name: String) -> Bool {
        let systemNames = SystemLLMConfig.providers.map(\.name)
        return userProviders.contains { $0.name == name } || systemNames.contains(name)
    }

    public func isModelNameTaken(_ name: String, inProvider providerName: String) -> Bool {
        // 检查用户模型
        if userModels.contains(where: { $0.name == name && $0.providerName == providerName }) {
            return true
        }
        // 检查系统预置模型
        if let provider = SystemLLMConfig.providers.first(where: { $0.name == providerName }),
           let models = provider.models,
           models.contains(name) {
            return true
        }
        return false
    }

    // MARK: - Logo Management

    public func saveLogo(for providerName: String, from sourceURL: URL) throws {
        let ext = sourceURL.pathExtension
        let destName = ext.isEmpty ? providerName : "\(providerName).\(ext)"
        let destURL = logoDir.appendingPathComponent(destName)

        // 删除旧 logo（可能扩展名不同）
        deleteLogo(for: providerName)

        // 启用安全范围访问（用户通过文件选择器获取的 URL）
        let needsSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.copyItem(at: sourceURL, to: destURL)
    }

    public func deleteLogo(for providerName: String) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: logoDir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            let nameWithoutExt = file.deletingPathExtension().lastPathComponent
            if nameWithoutExt == providerName {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    /// 从 Application Support/logos/ 加载用户 Logo
    #if os(macOS)
    public func loadUserLogo(for providerName: String) -> NSImage? {
        guard let files = try? FileManager.default.contentsOfDirectory(at: logoDir, includingPropertiesForKeys: nil) else { return nil }
        for file in files {
            let nameWithoutExt = file.deletingPathExtension().lastPathComponent
            if nameWithoutExt == providerName {
                return NSImage(contentsOf: file)
            }
        }
        return nil
    }
    #endif

    // MARK: - Conversion

    /// 将 UserLLMProvider 转为 LLMServiceProvider（供运行时使用）
    public func toServiceProvider(_ user: UserLLMProvider) -> LLMServiceProvider {
        LLMServiceProvider(
            name: user.name,
            displayName: user.displayName,
            logoName: nil,
            darkModeLogoName: nil,
            baseURL: user.baseURL,
            defaultModel: nil,
            models: nil,
            supportedFeatures: nil,
            description: nil,
            apiPlatfromLink: user.apiPlatfromLink
        )
    }

    /// 将 UserLLMModel 转为 LLMConfiguration（供运行时使用）
    public func toModelConfiguration(_ user: UserLLMModel) -> LLMConfiguration {
        var config = LLMConfiguration(name: user.name, origin: .user)
        config.providerID = user.providerName
        return config
    }
}
