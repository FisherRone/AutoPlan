//
//  DebugIntent.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/19.
//

#if DEBUG
import AppIntents
import AutoPlanCore
import OSLog
import SwiftUI

nonisolated private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AutoPlan", category: "Shortcuts")


/// 快捷指令：处理日程内容
/// 支持从共享菜单传入文本、图片，提取日程信息
/// 两种模式：「确认后保存」（默认）和「直接保存」
struct AutoPlanDebugIntent: AppIntent {
    
    
    static let title: LocalizedStringResource = "AutoPlan debug"
    
    
    static let description: IntentDescription = "从文本或图片中智能提取日程安排，支持多张图片"
    
    static let openAppWhenRun: Bool = false
    
    // MARK: - Parameters
    
    @Parameter(title: "文本内容", description: "要处理的文字描述")
    var textContent: String?
    
    @Parameter(title: "图片", description: "要识别的图片（支持多张）", default: [])
    var images: [IntentFile]
    
    @Parameter(title: "需要确认", description: "保存前是否需要确认", default: true)
    var requireConfirmation: Bool
    
    static var parameterSummary: some ParameterSummary {
        Summary("提取 \(\.$textContent) 中的日程") {
            \.$images
            \.$requireConfirmation
        }
    }
    
    // MARK: - Perform
    
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        logger.info("🚀 ProcessContentIntent 开始执行")
        
        // 1. 将 IntentFile 转换为 CGImage
        var cgImages: [CGImage] = []
        for file in images {
            if let cgImage = try? await convertToCGImage(file) {
                cgImages.append(cgImage)
            } else {
                logger.warning("⚠️ 无法转换图片: \(file.filename)")
            }
        }
        
        // 2. 调用引擎识别
        let events: [EventItem]
        do {
            events = try await AutoPlanEngine.process(
                textContent ?? "",
                cgImages: cgImages.isEmpty ? nil : cgImages
            )
        } catch AutoPlanError.noItemsRecognized {
            // 未识别到任何日程
            return .result(
                view: ErrorSnippetView(message: "未识别到任何日程或提醒事项。")
            )
        } catch {
            logger.error("❌ 引擎处理失败: \(error.localizedDescription)")
            throw error
        }
        
        guard !events.isEmpty else {
            return .result(view: ErrorSnippetView(message: "识别结果为空。"))
        }
        
        // 3. 根据模式处理
        if requireConfirmation {
            // ---------- 需确认模式 ----------
            logger.info("🔔 进入确认模式，共 \(events.count) 项待确认")
            
            // 展示预览并要求确认
            try await requestConfirmation(
                actionName: .add, dialog: "找到 \(events.count) 个日程，确认保存吗？",
                content: {
                    EventPreviewSnippetView(events: events)
                }
            )
            
            // 用户确认，执行保存（仅保存 isSelected == true 的项）
            let selectedEvents = events.filter { $0.isSelected }
            guard !selectedEvents.isEmpty else {
                return .result(view: ErrorSnippetView(message: "没有选中任何日程。"))
            }
            
            let (summary, savedEvents) = try await AutoPlanEngine.saveItems(selectedEvents)
            logger.info("✅ 保存完成: \(summary)")
            
            return .result(view: EventSavedSnippetView(events: savedEvents))
            
        } else {
            // ---------- 直接模式 ----------
            logger.info("⚡ 进入直接模式，自动保存 \(events.count) 项")
            
            let selectedEvents = events.filter { $0.isSelected }
            let (summary, savedEvents) = try await AutoPlanEngine.saveItems(selectedEvents)
            logger.info("✅ 自动保存完成: \(summary)")
            
            return .result(view: EventSavedSnippetView(events: savedEvents))
        }
    }
    
    // MARK: - Helpers
    
    /// 将 IntentFile 转换为 CGImage
    private func convertToCGImage(_ file: IntentFile) async throws -> CGImage? {
        let data = file.data
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return uiImage.cgImage
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }
}


#endif
