//
//  LLMManager.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/21.
//

import Foundation
import OSLog


// MARK: - JSON 解码模型

private struct LLMProviderDTO: Decodable {
    let name: String
    let displayName: String
    let logoName: String?
    let darkModeLogoName: String?
    let defaultBaseURL: String
    let defaultModel: String?
    let models: [String]?
    let supportedFeatures: [String]?
    let description: String?
}

private struct LLMConfigsContainer: Decodable {
    let LLMProviders: [LLMProviderDTO]
}


struct LLMConfigLoader {
    private static let logger = Logger(subsystem: "com.autoplan.core", category: "LLMConfig")
    
    static func loadDefaultConfigs() -> (providers: [LLMServiceProvider], models: [LLMConfiguration])? {
        guard let url = Bundle.module.url(forResource: "LLMConfigs", withExtension: "json") else {
            logger.error("❌ JSON 文件未找到")
            return nil
        }
        logger.info("📄 找到 JSON 文件: \(url.lastPathComponent)")
        
        guard let data = try? Data(contentsOf: url) else {
            logger.error("❌ 无法读取 JSON 文件内容")
            return nil
        }
        
        let container: LLMConfigsContainer
        do {
            container = try JSONDecoder().decode(LLMConfigsContainer.self, from: data)
            logger.info("✅ JSON 解析成功")
        } catch {
            logger.error("❌ JSON 解析失败: \(error.localizedDescription)")
            return nil
        }
        
        let providers = container.LLMProviders.map { dto in
            LLMServiceProvider(
                name: dto.name,
                displayName: dto.displayName,
                logoName: dto.logoName,
                darkModeLogoName: dto.darkModeLogoName,
                defaultBaseURL: dto.defaultBaseURL,
                defaultModel: dto.defaultModel,
                models: dto.models,
                supportedFeatures: dto.supportedFeatures,
                description: dto.description
            )
        }
        logger.info("📦 解析到 \(providers.count) 个 Provider")

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
        logger.info("📦 解析到 \(models.count) 个 Model")
        
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
    private let userModels: () -> [LLMConfiguration]

    init(
        systemProviders: [LLMServiceProvider],
        userModels: @escaping () -> [LLMConfiguration]
    ) {
        self.systemProviders = systemProviders
        self.userModels = userModels
    }

    /// 所有可用模型：系统预置 + 用户自定义
    var allModels: [LLMConfiguration] {
        let system = SystemLLMConfig.models      // 编译期常量
        return system + userModels()
    }

    func provider(for providerID: String) -> LLMServiceProvider? {
        systemProviders.first { $0.id == providerID }
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
            maxTokens: maxTokens
        )
    }
}
