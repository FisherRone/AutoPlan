//
//  AutoPlanCore/Model/LLMConfiguration.swift
//  AutoPlanCore
//
//  Created by 荣子鱼 on 2025/12/21.
//

import Foundation
import AppKit

// 功能设计：
// 1. 默认提供一些模型。
// 2. 用户可自定义模型。必须填 modelName baseURL 和 apikey
// 3. 用户自定义模型可填写提供商，但仅供 ui 展示，不使用服务商的默认 url
// 4. 用户自定义模型不填写 displayName 时，UI 用modelName来替代展示。
// 5. 用户不可以修改系统默认提供的配置。

// 一个 OpenAI 兼容的 LLM 服务配置
/// ⚠️ 此结构中**不包含 API Key**。
/// Key 通过 `providerID` 从文件（Application Support 下的 api_keys.json）单独读取。
public struct LLMConfiguration: Codable, Sendable, Identifiable {
    public var id = UUID()
    public var displayName: String?                  // App 界面中展示的名字
    public var providerID: String?              // 对应 LLMServiceProvider.id
    public var name: String               // 实际请求时用的 model 值，可覆盖默认
    public var baseURL: String?                // 自定义地址，nil 则使用 Provider 的默认值
    public var extraParameters: [String: CodableValue] = [:]
    public var origin: LLMConfigurationOrigin = .user
    public var display: Bool = true

    /// 获得最终请求用的 baseURL
    public func resolvedBaseURL(using provider: LLMServiceProvider?) -> String {
        baseURL ?? provider?.defaultBaseURL ?? ""
    }
}

extension LLMConfiguration {
    public var uiDisplayName: String { displayName ?? name }
}

extension LLMConfiguration {
    enum CommonExtraKey: String {
        case reasoningEffort = "reasoning_effort"
        case maxTokens = "max_tokens"
        case temperature = "temperature"
        // ...
    }
}

extension LLMConfiguration {
    public var isValidForRequest: Bool {
        guard !name.isEmpty else { return false }
        // 系统配置有 provider 作为回退，用户配置必须有 baseURL
        if origin == .user && (baseURL == nil || baseURL!.isEmpty) {
            return false
        }
        return true
    }
}


public enum LLMConfigurationOrigin: String, Sendable, Codable {
    case system      // 系统预置，未经用户修改
    case user        // 用户完全自建
}

public struct LLMServiceProvider: Codable, Sendable, Identifiable {
    /// 唯一标识，如 "deepseek", "openai", "azure"
    public var id: String { name }
    public let name: String            // 服务商标识符
    public let displayName: String     // 面向用户的名称，如 "DeepSeek"
    public let logoName: String?       // SF Symbol 或 Assets 中的图片名（浅色模式）
    public let darkModeLogoName: String?  // 深色模式下的 Logo 图片名
    public let defaultBaseURL: String  // 该服务商的默认 API 地址，如 "https://api.deepseek.com/v1"
    public let defaultModel: String?   // 推荐默认模型，如 "deepseek-chat"
    public let models: [String]?       // 该服务商支持的模型列表
    public let supportedFeatures: [String]? // 可选功能标签: "streaming", "reasoning", "function_calling"
    public let description: String?    // 简介
    public let apiPlatfromLink: String? // 该服务商 API Key 管理页面链接
    
    /// 从 AutoPlanCore 模块 Bundle 加载 Logo 图片
    #if os(macOS)
    public func loadLogo() -> NSImage? {
        let effectiveLogoName: String?
        if let darkLogo = darkModeLogoName,
           NSApp.effectiveAppearance.bestMatch(from: [.darkAqua]) == .darkAqua {
            effectiveLogoName = darkLogo
        } else {
            effectiveLogoName = logoName
        }

        guard let logoName = effectiveLogoName else { return nil }
        let nameWithoutExt = (logoName as NSString).deletingPathExtension
        let ext = (logoName as NSString).pathExtension
        if let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext) {
            return NSImage(contentsOf: url)
        }
        return nil
    }
    #endif
}


// 支持 Codable 的任意值容器，方便持久化字典
public enum CodableValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    var value: Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        }
    }
}


// MARK: 调用时的模型
public struct LLMRequestContext {
    public let baseURL: String
    public let apiKey: String
    public let model: String
    public var temperature: Double? = 1.0
    public var maxTokens: Int? = 2048
    public let providerName: String

    public init(baseURL: String, apiKey: String, model: String, temperature: Double? = 1.0, maxTokens: Int? = 2048, providerName: String = "") {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.providerName = providerName
    }
}
