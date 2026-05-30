//
//  LLMClient.swift
//  AutoPlanCore
//
//  Created by 荣子鱼 on 2025/12/21.
//

import Foundation
import OSLog

// MARK: - 网络层协议（用于测试注入）

public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}


// MARK: - 基础数据结构
enum LLMError: Error, LocalizedError {
    case networkError(Error)
    case serverError(statusCode: Int)
    case noContent
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let err): return String(localized: "网络连接错误: \(err.localizedDescription)")
        case .serverError(let code): return String(localized: "服务器报错 (代码: \(code))")
        case .noContent: return String(localized: "AI 未返回有效内容")
        case .decodingFailed(let err): return String(localized: "数据解析失败: \(err.localizedDescription)")
        }
    }
}

// MARK: - 连通性测试

public struct ConnectionTestResult: Sendable {
    public let model: String
    public let providerID: String
    public let success: Bool
    public let latencyMs: Int?
    public let error: String?

    nonisolated public static func success(model: String, providerID: String, latencyMs: Int) -> ConnectionTestResult {
        ConnectionTestResult(model: model, providerID: providerID, success: true, latencyMs: latencyMs, error: nil)
    }

    nonisolated public static func failure(model: String, providerID: String, error: String) -> ConnectionTestResult {
        ConnectionTestResult(model: model, providerID: providerID, success: false, latencyMs: nil, error: error)
    }
}

extension LLMClient {
    public func testConnection(context: LLMRequestContext, model: String, providerID: String) async -> ConnectionTestResult {
        let start = ContinuousClock.now
        do {
            _ = try await getResponse(prompt: "hi", context: context)
            let elapsed = ContinuousClock.now - start
            let ms = Int(elapsed.components.seconds * 1000 + Int64(Double(elapsed.components.attoseconds) / 1e9))
            return .success(model: model, providerID: providerID, latencyMs: ms)
        } catch {
            return .failure(model: model, providerID: providerID, error: error.localizedDescription)
        }
    }
}

// MARK: - 核心服务（门面）

public struct LLMClient: Sendable {
    public static let shared = LLMClient()
    private let parser = JsonParser()
    private let logger = Logger(subsystem: "com.autoplan.client", category: "LLM")
    private let openAIProvider: OpenAICompatibleProvider
    private let anthropicProvider: AnthropicProvider

    init(session: any URLSessionProtocol = URLSession.shared) {
        self.openAIProvider = OpenAICompatibleProvider(session: session)
        self.anthropicProvider = AnthropicProvider(session: session)
    }

    // MARK: - Public API

    /// 结构化生成
    func generate<T: Decodable>(prompt: String, context: LLMRequestContext, as responseType: T.Type) async throws -> T {
        let rawContent = try await getResponse(prompt: prompt, context: context)
        return try parser.parse(rawContent: rawContent, as: T.self)
    }

    // MARK: - Private Logic

    func getResponse(prompt: String, context: LLMRequestContext) async throws -> String {
        let provider = resolveProvider(for: context.providerName)
        return try await provider.generate(prompt: prompt, context: context)
    }

    private func resolveProvider(for name: String) -> any LLMAPIProvider {
        name.lowercased() == "claude" ? anthropicProvider : openAIProvider
    }
}
