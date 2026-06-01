//
//  LLMConfigs.swift
//  AutoPlanCore
//
//  Created by 荣子鱼 on 2025/12/21.
//

import Foundation

/// LLM 服务商预置配置，硬编码替代 LLMConfigs.json
enum LLMConfigs {
    static let providers: [LLMServiceProvider] = [
        LLMServiceProvider(
            name: "deepseek",
            displayName: "DeepSeek",
            logoName: "deepseekLogo.svg",
            darkModeLogoName: nil,
            baseURL: "https://api.deepseek.com",
            defaultModel: "deepseek-v4-lite",
            models: ["deepseek-v4-flash", "deepseek-v4-pro"],
            supportedFeatures: nil,
            description: nil,
            apiPlatfromURL: URL(string: "https://platform.deepseek.com/api_keys"),
            noThinkingModeStyle: .thinkingType
        ),
        LLMServiceProvider(
            name: "xiaomi",
            displayName: "Xiaomi",
            logoName: "xiaomiLogo.svg",
            darkModeLogoName: nil,
            baseURL: "https://api.xiaomimimo.com/v1",
            defaultModel: "mimo-v2.5",
            models: ["mimo-v2.5", "mimo-v2.5-pro"],
            supportedFeatures: nil,
            description: nil,
            apiPlatfromURL: URL(string: "https://platform.xiaomimimo.com/console/api-keys"),
            noThinkingModeStyle: .thinkingType
        ),
        LLMServiceProvider(
            name: "openai",
            displayName: "OpenAI",
            logoName: "OpenAILogoBlack.svg",
            darkModeLogoName: "OpenAILogoWhite.svg",
            baseURL: "https://api.openai.com/v1",
            defaultModel: "gpt-5.4-mini",
            models: ["gpt-5.4-mini", "gpt-5.5", "gpt-5.4"],
            supportedFeatures: nil,
            description: nil,
            apiPlatfromURL: URL(string: "https://platform.openai.com/api-keys"),
            noThinkingModeStyle: .reasoningEffort
        ),
        LLMServiceProvider(
            name: "anthropic",
            displayName: "Anthropic",
            logoName: "AnthropicLogoBlack.svg",
            darkModeLogoName: "AnthropicLogoWhite.svg",
            baseURL: "https://api.anthropic.com/v1/messages",
            defaultModel: "claude-sonnet-4-6",
            models: ["claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5"],
            supportedFeatures: nil,
            description: nil,
            apiPlatfromURL: URL(string: "https://platform.claude.com/settings/keys"),
            noThinkingModeStyle: .noParam
        ),
    ]
}
