//
//  ResponseParser.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/10.
//


//  ResponseParser.swift

import Foundation

struct JsonParser {
    /// 从 LLM 原始返回内容中提取 JSON 并解码为指定类型
    func parse<T: Decodable>(rawContent: String, as type: T.Type) throws -> T {
        let jsonString = extractJSON(from: rawContent)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw JsonParserError.invalidUTF8String
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw JsonParserError.decodingFailed(underlying: error)
        }
    }
    
    // MARK: - 私有方法
    
    /// 从 LLM 返回文本中提取 JSON 部分
    private func extractJSON(from text: String) -> String {
        // 优先匹配 ```json ... ``` 代码块
        if let match = text.firstMatch(of: #/```json\s*(.*?)\s*```/#.dotMatchesNewlines()) {
            return String(match.output.1)
        }
        
        // 兜底：取最外层的大括号或中括号内容
        if let start = text.firstIndex(where: { $0 == "{" || $0 == "[" }),
           let end = text.lastIndex(where: { $0 == "}" || $0 == "]" }),
           start < end {
            return String(text[start...end])
        }
        
        // 都没匹配到，原样返回（可能由上层处理错误）
        return text
    }
}

// MARK: - 错误定义

enum JsonParserError: Error, LocalizedError {
    case invalidUTF8String
    case decodingFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidUTF8String:
            return String(localized: "无法将提取的 JSON 字符串转换为 UTF-8 数据")
        case .decodingFailed:
            return String(localized: "AI 返回格式异常，请重试")
        }
    }
}
