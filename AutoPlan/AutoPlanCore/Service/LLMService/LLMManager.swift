//
//  LLMManager.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/21.
//

import Foundation
import SwiftyBeaver

struct LLMConfigLoader {
    
    static func loadDefaultConfigs() -> (providers: [LLMServiceProvider], models: [LLMConfiguration])? {
        let providers = LLMConfigs.providers
        logger.info("📦 使用 \(providers.count) 个预置 Provider", context: "LLMConfig")

        // 从 Provider 的 models 字段生成系统预置模型配置
        let models = providers.flatMap { provider -> [LLMConfiguration] in
            guard let modelNames = provider.models else { return [] }
            return modelNames.map { modelName in
                var config = LLMConfiguration(
                    name: modelName,
                    origin: .system
                )
                config.providerID = provider.name
                return config
            }
        }
        logger.info("📦 生成 \(models.count) 个系统预置 Model", context: "LLMConfig")
        
        return (providers, models)
    }
}

public enum SystemLLMConfig {
    public static let providers: [LLMServiceProvider] = {
        guard let (providers, _) = LLMConfigLoader.loadDefaultConfigs() else { return [] }
        return providers
    }()
    public static let models: [LLMConfiguration] = {
        guard let (_, models) = LLMConfigLoader.loadDefaultConfigs() else { return [] }
        return models
    }()
    
    public static func load() {
        // 在 App 启动时调用一次，内部解析 YAML 并赋值给 providers, models
    }
}

struct LLMService {
    private let systemProviders: [LLMServiceProvider]
    private let userProviders: () -> [LLMServiceProvider]
    private let userModels: () -> [LLMConfiguration]

    init(
        systemProviders: [LLMServiceProvider],
        userProviders: @escaping () -> [LLMServiceProvider] = { [] },
        userModels: @escaping () -> [LLMConfiguration] = { [] }
    ) {
        self.systemProviders = systemProviders
        self.userProviders = userProviders
        self.userModels = userModels
    }

    /// 所有可用模型：系统预置 + 用户自定义
    var allModels: [LLMConfiguration] {
        let system = SystemLLMConfig.models      // 编译期常量
        return system + userModels()
    }

    /// 所有服务商：系统预置 + 用户自定义
    var allProviders: [LLMServiceProvider] {
        systemProviders + userProviders()
    }

    func provider(for providerID: String) -> LLMServiceProvider? {
        allProviders.first { $0.id == providerID }
    }

    // MARK: - 构建请求上下文
    func requestContext(for model: LLMConfiguration) -> LLMRequestContext? {
        // 1. 基础有效性检查
        guard model.isValidForRequest else { return nil }

        // 2. 解析 baseURL
        let provider: LLMServiceProvider?
        if let providerID = model.providerID {
            provider = self.provider(for: providerID)
        } else {
            provider = nil
        }
        let baseURL = model.resolvedBaseURL(using: provider)

        // 3. 从 Keychain 读取 API Key
        guard let apiKey = APIKeyStore.read(for: model.providerID ?? model.id.uuidString) else {
            return nil
        }

        // 4. 从 extraParameters 提取常见可配置项
        var temperature: Double = 1.0
        var maxTokens: Int? = nil

        if let tempVal = model.extraParameters[LLMConfiguration.CommonExtraKey.temperature.rawValue] {
            switch tempVal {
            case .double(let d): temperature = d
            case .int(let i):    temperature = Double(i)
            default: break
            }
        }

        if let tokenVal = model.extraParameters[LLMConfiguration.CommonExtraKey.maxTokens.rawValue] {
            switch tokenVal {
            case .int(let i): maxTokens = i
            case .double(let d): maxTokens = Int(d)
            default: break
            }
        }

        return LLMRequestContext(
            baseURL: baseURL,
            apiKey: apiKey,
            model: model.name,
            temperature: temperature,
            maxTokens: maxTokens,
            providerName: provider?.name ?? ""
        )
    }
}
