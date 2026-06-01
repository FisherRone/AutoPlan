//
//  NoThinkingModeDetector.swift
//  AutoPlanCore
//
//  Created by 荣子鱼 on 2026/6/1.
//

import Foundation
import SwiftyBeaver

actor NoThinkingModeDetector {
    static let shared = NoThinkingModeDetector()

    private var detectedStyles: [String: NoThinkingModeStyle] = [:]
    private var inProgress: [String: Task<NoThinkingModeStyle, Never>] = [:]

    func detect(
        baseURL: String,
        apiKey: String,
        model: String,
        providerName: String
    ) async -> NoThinkingModeStyle {
        if let cached = detectedStyles[providerName] {
            return cached
        }

        if let existingTask = inProgress[providerName] {
            return await existingTask.value
        }

        let task = Task<NoThinkingModeStyle, Never> {
            let result = await performDetection(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                providerName: providerName
            )
            detectedStyles[providerName] = result
            inProgress[providerName] = nil
            return result
        }
        inProgress[providerName] = task
        return await task.value
    }

    private func performDetection(
        baseURL: String,
        apiKey: String,
        model: String,
        providerName: String
    ) async -> NoThinkingModeStyle {
        let chatURLString = baseURL.hasSuffix("/chat/completions") ? baseURL : baseURL + "/chat/completions"

        if await testThinkingType(urlString: chatURLString, apiKey: apiKey, model: model) {
            logger.info("🔍 探测结果: \(providerName) → .thinkingType", context: "NoThinkingModeDetector")
            return .thinkingType
        }

        if await testReasoningEffort(urlString: chatURLString, apiKey: apiKey, model: model) {
            logger.info("🔍 探测结果: \(providerName) → .reasoningEffort", context: "NoThinkingModeDetector")
            return .reasoningEffort
        }

        logger.info("🔍 探测结果: \(providerName) → .noParam", context: "NoThinkingModeDetector")
        return .noParam
    }

    private func testThinkingType(urlString: String, apiKey: String, model: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "hi"]],
            "stream": false,
            "thinking": ["type": "disabled"]
        ]

        return await sendTestRequest(url: url, apiKey: apiKey, body: body)
    }

    private func testReasoningEffort(urlString: String, apiKey: String, model: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "hi"]],
            "stream": false,
            "reasoning_effort": "none"
        ]

        return await sendTestRequest(url: url, apiKey: apiKey, body: body)
    }

    private func sendTestRequest(url: URL, apiKey: String, body: [String: Any]) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = bodyData
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResp.statusCode)
        } catch {
            return false
        }
    }
}
