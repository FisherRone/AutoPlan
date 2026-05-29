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
        case .networkError(let err): return "网络连接错误: \(err.localizedDescription)"
        case .serverError(let code): return "服务器报错 (代码: \(code))"
        case .noContent: return "AI 未返回有效内容"
        case .decodingFailed(let err): return "数据解析失败: \(err.localizedDescription)"
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

    public static func success(model: String, providerID: String, latencyMs: Int) -> ConnectionTestResult {
        ConnectionTestResult(model: model, providerID: providerID, success: true, latencyMs: latencyMs, error: nil)
    }

    public static func failure(model: String, providerID: String, error: String) -> ConnectionTestResult {
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

// MARK: - 核心服务

public struct LLMClient: Sendable {
    public static let shared = LLMClient()
    private let parser = JsonParser()
    
    
    private let logger = Logger(subsystem: "com.autoplan.client", category: "LLM")
    private let session: any URLSessionProtocol

    init(session: any URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    // MARK: - Public API

    /// 结构化生成
    func generate<T: Decodable>(prompt: String, context: LLMRequestContext, as responseType: T.Type) async throws -> T {
        let rawContent = try await getResponse(prompt: prompt, context: context)
        return try parser.parse(rawContent: rawContent, as: T.self)
    }

    // MARK: - Private Logic

    func getResponse(prompt: String, context: LLMRequestContext) async throws -> String {
        guard let url = URL(string: context.baseURL) else {
            throw LLMError.networkError(URLError(.badURL))
        }
        let payload = ChatRequest(
            model: context.model,
            messages: [.init(role: "user", content: prompt)],
            temperature: context.temperature ?? 1.0
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(context.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        
        logger.info("📨 发送 LLM 请求，模型: \(payload.model)")
        logger.debug("📝 提示词内容:\n\(prompt)")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LLMError.networkError(error)
        }
        
        guard let httpResp = response as? HTTPURLResponse else {
            throw LLMError.networkError(URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResp.statusCode) else {
            logger.error("API Error: \(String(data: data, encoding: .utf8) ?? "Unknown")")
            throw LLMError.serverError(statusCode: httpResp.statusCode)
        }
        
        let apiResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = apiResponse.choices.first?.message.content else {
            throw LLMError.noContent
        }
        print(content)
        return content
    }

    

    // MARK: - API DTOs
    
    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let stream: Bool = false
        // let maxTokens: Int = 4096 // DeepSeek 最大 tokens，按需开启

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }
}
