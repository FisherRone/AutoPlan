//
//  EventSnippetIntent.swift
//  AutoPlan
//
//  Interactive Snippet for Shortcuts integration.
//
import AppIntents
import AutoPlanCore
import OSLog
import SwiftUI

nonisolated private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AutoPlan", category: "Shortcuts")

// MARK: - Preview Snippet Intent (确认对话框用)

/// 展示待确认日程的预览卡片（用于 requestConfirmation）
struct EventPreviewSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "日程预览"
    static let description: IntentDescription = "展示识别到的日程信息，等待确认"
    
    @Parameter(title: "事件数据", description: "Base64 编码的事件列表")
    var eventsDataBase64: String
    
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        logger.info("📋 EventPreviewSnippetIntent 开始执行")
        
        guard let data = Data(base64Encoded: eventsDataBase64) else {
            return .result(view: Text("数据解析失败"))
        }
        
        let events = try JSONDecoder().decode([EventItem].self, from: data)
        return .result(view: EventPreviewSnippetView(events: events))
    }
}

// MARK: - Result Snippet Intent (结果展示用)

/// 展示已保存日程的预览卡片
struct EventSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "日程预览"
    static let description: IntentDescription = "展示已保存的日程信息"
    
    @Parameter(title: "事件数据", description: "Base64 编码的事件列表")
    var eventsDataBase64: String
    
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        logger.info("📋 EventSnippetIntent 开始执行")
        
        guard let data = Data(base64Encoded: eventsDataBase64) else {
            logger.error("❌ Base64 解码失败")
            return .result(view: Text("数据解析失败"))
        }
        
        let events = try JSONDecoder().decode([EventItem].self, from: data)
        logger.info("✅ 成功解码 \(events.count, privacy: .public) 个事件")
        
        return .result(view: EventSavedSnippetView(events: events))
    }
}

// MARK: - Open App Intent

/// 打开 App 的基础 Intent
struct OpenAutoPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "打开 AutoPlan"
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
