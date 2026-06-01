//
//  OpenAICompatibleProvider.swift
//  AutoPlanCore
//
//  Created by 荣子鱼 on 2026/5/30.
//

import Foundation
import SwiftyBeaver

/// OpenAI 兼容格式的 LLM API 实现
struct OpenAICompatibleProvider: LLMAPIProvider {
    private let session: any URLSessionProtocol

    init(session: any URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    func generate(prompt: String, context: LLMRequestContext) async throws -> String {
        let urlString = context.baseURL.hasSuffix("/chat/completions") ? context.baseURL : context.baseURL + "/chat/completions"
        guard let url = URL(string: urlString) else {
            throw LLMError.networkError(URLError(.badURL))
        }

        let thinkingParam: ChatRequest.ThinkingParam?
        let reasoningEffortParam: String?
        switch context.noThinkingModeStyle {
        case .thinkingType:
            thinkingParam = .init()
            reasoningEffortParam = nil
        case .reasoningEffort:
            thinkingParam = nil
            reasoningEffortParam = "none"
        case .noParam, .unknown, .none:
            thinkingParam = nil
            reasoningEffortParam = nil
        }

        let payload = ChatRequest(
            model: context.model,
            messages: [.init(role: "user", content: prompt)],
            temperature: context.temperature ?? 1.0,
            thinking: thinkingParam,
            reasoningEffort: reasoningEffortParam
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(context.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        logger.info("📨 发送 LLM 请求，模型: \(payload.model)", context: "OpenAI")
        logger.debug("📝 提示词内容:\n\(prompt)", context: "OpenAI")

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
            logger.error("API Error: \(String(data: data, encoding: .utf8) ?? "Unknown")", context: "OpenAI")
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
        let thinking: ThinkingParam?
        let reasoningEffort: String?

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, stream, thinking
            case reasoningEffort = "reasoning_effort"
        }

        struct Message: Encodable {
            let role: String
            let content: String
        }

        struct ThinkingParam: Encodable {
            let type: String = "disabled"
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
