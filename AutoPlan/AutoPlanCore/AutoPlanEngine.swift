// AutoPlanCore/Sources/AutoPlanEngine.swift
import Foundation
import CoreGraphics
import SwiftyBeaver

public enum AutoPlanError: Error, LocalizedError {
    case noItemsRecognized
    case saveFailed(itemTitle: String)
    case modelNameNotSelected
    case modelConfigNotFound(String)
    case apiKeyNotConfigured(String)
    
    public var errorDescription: String? {
        switch self {
        case .noItemsRecognized:
            return String(localized: "未能识别到任何日程或提醒事项")
        case .saveFailed(let itemTitle):
            return String(localized: "保存「\(itemTitle)」失败")
        case .modelNameNotSelected:
            return String(localized: "请先在 App 设置中选择一个模型")
        case .modelConfigNotFound(let name):
            return String(localized: "未找到模型「\(name)」的配置")
        case .apiKeyNotConfigured(let providerID):
            return String(localized: "服务商「\(providerID)」的 API Key 未配置")
        }
    }
}

public struct AutoPlanEngine {
    
    // MARK: - 公开接口
    /// 包含以下模式
    /// 1. 文本 + 图片模式（后续扩充至其他附件）
    /// 2. 日程 -> 加对应提醒事项
    /// 3. 提醒事项 -> 拆分子任务
    
    
    public static func process(_ input: String = "", cgImages: [CGImage]? = nil, context: LLMRequestContext? = nil) async throws -> [EventItem] {
        logger.info("▶️ process 开始, input.len=\(input.count), images=\(cgImages?.count ?? 0)", context: "Engine")
        
        // 1. OCR: 对每张图片执行文字识别
        var ocrResults: [Int: String] = [:]
        if let images = cgImages {
            for (index, image) in images.enumerated() {
                do {
                    let text = try await ocr(cgImage: image)
                    ocrResults[index] = text
                } catch {
                    logger.error("❌ OCR failed for image \(index): \(error.localizedDescription)", context: "Engine")
                }
            }
        }
        
        // 2. 构建配置（获取用户可写日历/提醒列表，合并持久化设置）
        logger.info("📋 获取系统列表...", context: "Engine")
        let settings = try await ListStore.refresh()
        logger.info("✅ 获取到 \(settings.userCalendarLists.count) 个日历列表, \(settings.userReminderLists.count) 个提醒列表", context: "Engine")
        
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
        } else {
            requestContext = try resolveRequestContext()
        }
        
        logger.info("📤 调用 LLM...", context: "Engine")
        let eventItems = try await getEventItem(prompt: fullPrompt, settings: settings, context: requestContext)
        logger.info("✅ LLM 返回 \(eventItems.count) 个日程项", context: "Engine")
        
        return eventItems
    }
    
    /// 从 UserDefaults 读取用户选中的模型，构建 LLMRequestContext
    private static func resolveRequestContext() throws -> LLMRequestContext {
        let selectedModelName = UserDefaults.standard.string(forKey: "selectedModelName") ?? ""
        guard !selectedModelName.isEmpty else {
            logger.error("resolveRequestContext 失败: selectedModelName 为空", context: "Engine")
            throw AutoPlanError.modelNameNotSelected
        }
        logger.debug("selectedModelName = \(selectedModelName)", context: "Engine")
        
        let matchedModel = SystemLLMConfig.models.first { $0.name == selectedModelName }
        guard let model = matchedModel else {
            let availableNames = SystemLLMConfig.models.map { $0.name }
            logger.error("resolveRequestContext 失败: 未找到模型 \(selectedModelName), 可用模型: \(availableNames)", context: "Engine")
            throw AutoPlanError.modelConfigNotFound(selectedModelName)
        }
        logger.debug("找到模型: \(model.name), providerID: \(model.providerID ?? "nil")", context: "Engine")
        
        let service = LLMService(
            systemProviders: SystemLLMConfig.providers,
            userModels: { [] }
        )
        guard let context = service.requestContext(for: model) else {
            logger.error("resolveRequestContext 失败: API Key 未配置, providerID=\(model.providerID ?? "nil")", context: "Engine")
            throw AutoPlanError.apiKeyNotConfigured(model.providerID ?? selectedModelName)
        }
        return context
    }
    
    public static func saveItems(_ items: [EventItem]) async throws -> (summary: String, items: [EventItem]) {
        return try await saveEventItem(eventItems: items)
    }
    
    // MARK: - LLM 识别与增强
    
    
    private static func getEventItem(prompt: String, settings: CoreConfiguration, context: LLMRequestContext) async throws -> [EventItem] {
        // 4. 调用 LLM，解析 JSON 为日程项
        logger.info("🤖 LLM 解析中...", context: "Engine")
        let tempItems: [TempEventItem] = try await LLMClient.shared.generate(
            prompt: prompt,
            context: context,
            as: [TempEventItem].self
        )
        logger.info("📦 LLM 原始返回 \(tempItems.count) 项", context: "Engine")
        
        guard !tempItems.isEmpty else {
            logger.warning("⚠️ LLM 返回了空数组", context: "Engine")
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
        let summary = String(localized: "已识别 \(eventItems.count) 项，成功保存 \(savedCount) 项：\n\(titles)")
        return (summary, updatedItems)
    }
    
}

