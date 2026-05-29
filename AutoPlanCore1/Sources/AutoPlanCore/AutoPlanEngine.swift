// AutoPlanCore/Sources/AutoPlanEngine.swift
import Foundation
import CoreGraphics
import OSLog

private let logger = Logger(subsystem: "AutoPlanCore", category: "Engine")

public enum AutoPlanError: Error {
    case noItemsRecognized
    case saveFailed(itemTitle: String)
}

public struct AutoPlanEngine {
    
    // MARK: - 公开接口
    /// 包含以下模式
    /// 1. 文本 + 图片模式（后续扩充至其他附件）
    /// 2. 日程 -> 加对应提醒事项
    /// 3. 提醒事项 -> 拆分子任务
    
    
    public static func process(_ input: String = "", cgImages: [CGImage]? = nil, context: LLMRequestContext? = nil) async throws -> [EventItem] {
        logger.info("▶️ process 开始, input.len=\(input.count), images=\(cgImages?.count ?? 0)")
        
        // 1. OCR: 对每张图片执行文字识别
        var ocrResults: [Int: String] = [:]
        if let images = cgImages {
            for (index, image) in images.enumerated() {
                do {
                    let text = try await ocr(cgImage: image)
                    ocrResults[index] = text
                } catch {
                    ocrResults[index] = "[OCR failed: \(error.localizedDescription)]"
                }
            }
        }
        
        // 2. 构建配置（获取用户可写日历/提醒列表，合并持久化设置）
        logger.info("📋 获取系统列表...")
        let settings = try await ListStore.refresh()
        logger.info("✅ 获取到 \(settings.userCalendarLists.count) 个日历列表, \(settings.userReminderLists.count) 个提醒列表")
        
        // 3. 构造提示词（传入列表描述供 LLM 参考）
        let systemPrompt = PromptBuilder.buildSystemPrompt(
            calendarLists: settings.userCalendarLists,
            reminderLists: settings.userReminderLists
        )
        let userPrompt = PromptBuilder.buildUserPrompt(originalText: input, ocrResults: ocrResults)
        let fullPrompt = systemPrompt + "\n\n" + userPrompt
        
        // 解析请求上下文：优先使用传入的 context，否则从 UserDefaults 构建
        let requestContext: LLMRequestContext
        if let ctx = context {
            requestContext = ctx
        } else if let ctx = resolveRequestContext() {
            requestContext = ctx
        } else {
            throw AutoPlanError.noItemsRecognized
        }
        
        logger.info("📤 调用 LLM...")
        let eventItems = try await getEventItem(prompt: fullPrompt, settings: settings, context: requestContext)
        logger.info("✅ LLM 返回 \(eventItems.count) 个日程项")
        
        return eventItems
    }
    
    /// 从 UserDefaults 读取用户选中的模型，构建 LLMRequestContext
    private static func resolveRequestContext() -> LLMRequestContext? {
        let selectedModelName = UserDefaults.standard.string(forKey: "selectedModelName") ?? ""
        guard !selectedModelName.isEmpty else {
            logger.error("❌ resolveRequestContext 失败: selectedModelName 为空")
            return nil
        }
        logger.debug("selectedModelName = \(selectedModelName)")
        
        // 从系统配置中查找匹配的模型
        let matchedModel = SystemLLMConfig.models.first { $0.name == selectedModelName }
        guard let model = matchedModel else {
            let availableNames = SystemLLMConfig.models.map { $0.name }
            logger.error("❌ resolveRequestContext 失败: 未找到模型 \(selectedModelName), 可用模型: \(availableNames)")
            return nil
        }
        logger.debug("找到模型: \(model.name), providerID: \(model.providerID ?? "nil")")
        
        let service = LLMService(
            systemProviders: SystemLLMConfig.providers,
            userModels: { [] }
        )
        let context = service.requestContext(for: model)
        if context == nil {
            logger.error("❌ resolveRequestContext 失败: LLMService.requestContext 返回 nil (API Key 可能未配置)")
        }
        return context
    }
    
    public static func saveItems(_ items: [EventItem]) async throws -> (summary: String, items: [EventItem]) {
        return try await saveEventItem(eventItems: items)
    }
    
    // MARK: - LLM 识别与增强
    
    
    private static func getEventItem(prompt: String, settings: CoreConfiguration, context: LLMRequestContext) async throws -> [EventItem] {
        // 4. 调用 LLM，解析 JSON 为日程项
        logger.info("🤖 LLM 解析中...")
        let tempItems: [TempEventItem] = try await LLMClient.shared.generate(
            prompt: prompt,
            context: context,
            as: [TempEventItem].self
        )
        logger.info("📦 LLM 原始返回 \(tempItems.count) 项")
        
        guard !tempItems.isEmpty else {
            logger.warning("⚠️ LLM 返回了空数组")
            throw AutoPlanError.noItemsRecognized
        }
        
        // 5. 通过 EventEnricher 转换为 EventItem 并匹配系统日历
        let enrichedItems = EventEnricher.enrich(tempItems: tempItems, settings: settings)

        return enrichedItems
    }
    
    private static func saveEventItem(eventItems: [EventItem]) async throws -> (summary: String, items: [EventItem]) {
        var savedCount = 0
        var updatedItems = eventItems
        for i in updatedItems.indices where updatedItems[i].isSelected {
            try await EventService.shared.saveEventItem(updatedItems[i])
            updatedItems[i].status = .saved
            savedCount += 1
        }
        
        let titles = eventItems.map { "• \($0.title)" }.joined(separator: "\n")
        let summary = "已识别 \(eventItems.count) 项，成功保存 \(savedCount) 项：\n\(titles)"
        return (summary, updatedItems)
    }
    
}

