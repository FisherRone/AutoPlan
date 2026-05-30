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
            defaultBaseURL: "https://api.deepseek.com/chat/completions",
            defaultModel: "deepseek-v4-lite",
            models: ["deepseek-v4-flash", "deepseek-v4-pro"],
            supportedFeatures: nil,
            description: nil,
            apiPlatfromLink: "https://platform.deepseek.com/api_keys"
        ),
        LLMServiceProvider(
            name: "xiaomi",
            displayName: "Xiaomi",
            logoName: "xiaomiLogo.svg",
            darkModeLogoName: nil,
            defaultBaseURL: "https://api.xiaomimimo.com/v1/chat/completions",
            defaultModel: "mimo-v2.5",
            models: ["mimo-v2.5", "mimo-v2.5-pro"],
            supportedFeatures: nil,
            description: nil,
            apiPlatfromLink: "https://platform.xiaomimimo.com/console/api-keys"
        ),
        LLMServiceProvider(
            name: "openai",
            displayName: "OpenAI",
            logoName: "OpenAILogoBlack.svg",
            darkModeLogoName: "OpenAILogoWhite.svg",
            defaultBaseURL: "https://api.openai.com/v1/chat/completions",
            defaultModel: "gpt-5.4-mini",
            models: ["gpt-5.4-mini", "gpt-5.5", "gpt-5.4"],
            supportedFeatures: nil,
            description: nil,
            apiPlatfromLink: "https://platform.openai.com/api-keys"
        ),
        LLMServiceProvider(
            name: "claude",
            displayName: "Claude",
            logoName: nil,
            darkModeLogoName: nil,
            defaultBaseURL: "https://api.anthropic.com/v1/messages",
            defaultModel: "claude-sonnet-4-6",
            models: ["claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5"],
            supportedFeatures: nil,
            description: nil,
            apiPlatfromLink: "https://platform.claude.com/settings/keys"
        ),
    ]
}
