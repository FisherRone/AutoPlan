//
//  LLMAPIProvider.swift
//  AutoPlanCore
//
//  Created by 荣子鱼 on 2026/5/30.
//

import Foundation

/// LLM API 协议抽象
public protocol LLMAPIProvider: Sendable {
    func generate(prompt: String, context: LLMRequestContext) async throws -> String
}
