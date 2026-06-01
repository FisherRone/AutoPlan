//
//  OpenAIProvider.swift
//  AutoPlanCore
//
//  Created by 荣子鱼 on 2026/6/1.
//

import Foundation
import SwiftyBeaver

struct OpenAIProvider: LLMAPIProvider {
    private let session: any URLSessionProtocol

    init(session: any URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    func generate(prompt: String, context: LLMRequestContext) async throws -> String {
        let urlString = context.baseURL.hasSuffix("/responses") ? context.baseURL : context.baseURL + "/responses"
        guard let url = URL(string: urlString) else {
            throw LLMError.networkError(URLError(.badURL))
        }

        let payload = ResponsesRequest(
            model: context.model,
            input: [.init(role: "user", content: prompt)],
            reasoning: .init(effort: "none")
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(context.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        logger.info("📨 发送 OpenAI Responses 请求，模型: \(payload.model)", context: "OpenAI")
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
            logger.error("OpenAI API Error: \(String(data: data, encoding: .utf8) ?? "Unknown")", context: "OpenAI")
            throw LLMError.serverError(statusCode: httpResp.statusCode)
        }

        let apiResponse = try JSONDecoder().decode(ResponsesResponse.self, from: data)
        guard let messageOutput = apiResponse.output.first(where: { $0.type == "message" }),
              let content = messageOutput.content,
              let textBlock = content.first(where: { $0.type == "output_text" }),
              let text = textBlock.text else {
            throw LLMError.noContent
        }
        print(text)
        return text
    }

    private struct ResponsesRequest: Encodable {
        let model: String
        let input: [InputMessage]
        let reasoning: ReasoningParam

        struct InputMessage: Encodable {
            let role: String
            let content: String
        }

        struct ReasoningParam: Encodable {
            let effort: String
        }
    }

    private struct ResponsesResponse: Decodable {
        let output: [OutputItem]

        struct OutputItem: Decodable {
            let type: String
            let content: [ContentBlock]?

            enum CodingKeys: String, CodingKey {
                case type, content
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                type = try container.decode(String.self, forKey: .type)
                content = try? container.decodeIfPresent([ContentBlock].self, forKey: .content)
            }
        }

        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
    }
}
