//
//  LLMManager.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/21.
//

import Yams
import Foundation
import OSLog


struct LLMConfigLoader {
    private static let logger = Logger(subsystem: "com.autoplan.core", category: "LLMConfig")
    
    static func loadDefaultConfigs() -> (providers: [LLMServiceProvider], models: [LLMConfiguration])? {
        guard let url = Bundle.module.url(forResource: "LLMConfigs", withExtension: "yaml") else {
            logger.error("❌ YAML 文件未找到")
            return nil
        }
        logger.info("📄 找到 YAML 文件: \(url.lastPathComponent)")
        
        guard let yamlString = try? String(contentsOf: url) else {
            logger.error("❌ 无法读取 YAML 文件内容")
            return nil
        }
        logger.info("📄 YAML 文件大小: \(yamlString.count) 字符")
        
        var result: Any
        do {
            result = try Yams.load(yaml: yamlString)
            logger.info("✅ YAML 加载成功，类型: \(type(of: result))")
        } catch let error as Yams.YamlError {
            switch error {
            case .parser(_, let problem, let mark, _):
                logger.error("❌ YAML 解析器错误: \(problem) at line \(mark.line), column \(mark.column)")
            default:
                logger.error("❌ YAML 错误: \(error)")
            }
            return nil
        } catch {
            logger.error("❌ 未知错误: \(error)")
            return nil
        }
        
        guard let yaml = result as? [String: Any] else {
            logger.error("❌ YAML 根节点不是 [String: Any]，实际类型: \(type(of: result))")
            return nil
        }
        
        // 解析 Providers
        var providers: [LLMServiceProvider] = []
        if let providerList = yaml["LLMProviders"] as? [[String: Any]] {
            for dict in providerList {
                // 注意 YAML 中的别名在解析后已经被还原为实际字典，所以直接取值即可
                guard let name = dict["name"] as? String,
                      let displayName = dict["displayName"] as? String,
                      let defaultBaseURL = dict["defaultBaseURL"] as? String else {
                    logger.warning("⚠️ 跳过 Provider: 缺少必要字段")
                    continue
                }
                let logo = dict["logoName"] as? String
                let darkModeLogo = dict["darkModeLogoName"] as? String
                let defaultModel = dict["defaultModel"] as? String
                let models = dict["models"] as? [String]
                let features = dict["supportedFeatures"] as? [String]
                let desc = dict["description"] as? String
                let provider = LLMServiceProvider(
                    name: name,
                    displayName: displayName,
                    logoName: logo,
                    darkModeLogoName: darkModeLogo,
                    defaultBaseURL: defaultBaseURL,
                    defaultModel: defaultModel,
                    models: models,
                    supportedFeatures: features,
                    description: desc
                )
                providers.append(provider)
                logger.debug("  ✅ Provider: \(displayName) (URL: \(defaultBaseURL))")
            }
        }
        logger.info("📦 解析到 \(providers.count) 个 Provider")

        // 从 Provider 的 models 字段生成系统预置模型配置
        var models: [LLMConfiguration] = []
        for provider in providers {
            if let modelNames = provider.models {
                for modelName in modelNames {
                    var config = LLMConfiguration(
                        name: modelName,
                        origin: .system
                    )
                    config.providerID = provider.name
                    models.append(config)
                    logger.debug("  ✅ Model: \(modelName) (Provider: \(provider.displayName))")
                }
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
