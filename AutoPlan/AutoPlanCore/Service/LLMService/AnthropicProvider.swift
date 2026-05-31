//
//  AnthropicProvider.swift
//  AutoPlanCore
//
//  Created by 荣子鱼 on 2026/5/30.
//

import Foundation
import SwiftyBeaver

/// Anthropic Messages API 实现
struct AnthropicProvider: LLMAPIProvider {
    private let session: any URLSessionProtocol

    init(session: any URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    func generate(prompt: String, context: LLMRequestContext) async throws -> String {
        guard let url = URL(string: context.baseURL) else {
            throw LLMError.networkError(URLError(.badURL))
        }

        let maxTokens = context.maxTokens ?? 4096
        let payload = AnthropicRequest(
            model: context.model,
            maxTokens: maxTokens,
            messages: [.init(role: "user", content: prompt)],
            temperature: context.temperature ?? 1.0
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(context.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        logger.info("📨 发送 Anthropic 请求，模型: \(payload.model)", context: "Anthropic")
        logger.debug("📝 提示词内容:\n\(prompt)", context: "Anthropic")

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
            if let errorBody = String(data: data, encoding: .utf8) {
                logger.error("Anthropic API Error: \(errorBody)", context: "Anthropic")
            }
            throw LLMError.serverError(statusCode: httpResp.statusCode)
        }

        let apiResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let content = apiResponse.content.first(where: { $0.type == "text" })?.text else {
            throw LLMError.noContent
        }
        print(content)
        return content
    }

    // MARK: - API DTOs

    private struct AnthropicRequest: Encodable {
        let model: String
        let maxTokens: Int
        let messages: [Message]
        let temperature: Double

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case messages
            case temperature
        }

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct AnthropicResponse: Decodable {
        let content: [ContentBlock]

        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
    }
}
