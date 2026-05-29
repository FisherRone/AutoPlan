//
//  PromptBuilder.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/18.
//

import Foundation

public enum PromptBuilder {
    
    // MARK: - Core Properties
    
    /// UserDefaults key for custom prompt toggle
    private static let useCustomPromptKey = "useCustomExtractionPrompt"
    
    /// 系统提示词模板（Bundle 内 BasePrompt.txt，含 {{...}} 占位符）
    private static let systemTemplate: String = {
        guard let url = Bundle.module.url(forResource: "BasePrompt", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return "{{BASE_INSTRUCTION}}"
        }
        return content
    }()
    
    /// 系统默认指令内容（Bundle 内 BaseInstruction.txt）
    private static let systemDefaultInstruction: String = {
        guard let url = Bundle.module.url(forResource: "BaseInstruction", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return "默认兜底的 Prompt"
        }
        return content
    }()
    
    /// 每次调用时动态读取，根据开关决定使用自定义还是系统默认
    private static func baseInstruction() -> String {
        let useCustom = UserDefaults.standard.bool(forKey: useCustomPromptKey)
        if useCustom, let customURL = customPromptFileURL,
           let content = try? String(contentsOf: customURL, encoding: .utf8),
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content
        }
        return systemDefaultInstruction
    }
    
    /// 自定义提示词文件路径
    public static var customPromptFileURL: URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        print("DEBUG: customPromptFileURL = \(appSupport)")
        return appSupport.appendingPathComponent("AutoPlan/custom_base_prompt.txt")
    }
    
    /// 读取模板提示词（供 UI 预览）
    public static var templatePrompt: String {
        guard let url = Bundle.module.url(forResource: "TemplatePrompt", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return systemDefaultInstruction
        }
        return content
    }
    
    /// 确保自定义提示词文件存在，不存在则用系统默认内容创建
    public static func ensureCustomPromptFileExists() {
        guard let url = customPromptFileURL else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        excludeFromBackup(url: dir)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
    }

    // MARK: - Private Helpers

    /// 排除文件/目录不被 Time Machine 备份
    private static func excludeFromBackup(url: URL) {
        try? (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
    }

    /// 通用模板渲染：将 {{KEY}} 替换为对应内容，空内容或未匹配的占位符会被移除
    public static func renderTemplate(_ template: String, with blocks: [String: String?]) -> String {
        var result = template
        for (key, value) in blocks {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value ?? "")
        }
        // 移除未匹配的 {{...}} 占位符
        if let regex = try? NSRegularExpression(pattern: #"\{\{[^}]+\}\}"#) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return result
    }
    
    // MARK: - Public Methods
    
    static func buildSystemPrompt(
        calendarLists: [ListInfo] = [],
        reminderLists: [ListInfo] = [],
        refTags: [String] = []
    ) -> String {
        let blocks: [String: String?] = [
            "BASE_INSTRUCTION": baseInstruction(),
            "USER_INSTRUCTION": UserDefaults.standard.string(forKey: "userInstruction"),
            "CURRENT_TIME": buildTimeBlock(),
            "LISTS": buildListBlock(calendars: calendarLists, reminders: reminderLists),
            "TAGS": buildTagBlock(refTags: refTags),
            "DATE_WEEKDAY": generateCalendarString(startingFrom: Date())
        ]
        return renderTemplate(systemTemplate, with: blocks)
    }

    // MARK: - Block Builders

    private static func buildTimeBlock() -> String? {
        let now = Date()
        let timeString = now.formatted(
            .iso8601
            .year().month().day()
            .time(includingFractionalSeconds: false)
            .timeSeparator(.colon)
            .dateSeparator(.dash)
        ).replacingOccurrences(of: "T", with: " ")
        return "\(timeString). Only indicates the times of current request."
    }

    private static func buildListBlock(calendars: [ListInfo], reminders: [ListInfo]) -> String? {
        guard !calendars.isEmpty || !reminders.isEmpty else { return nil }
        return buildListPrompt(calendars: calendars, reminders: reminders)
    }

    private static func buildTagBlock(refTags: [String]) -> String? {
        guard !refTags.isEmpty else { return nil }
        return """
        [\(refTags.map { "\"\($0)\"" }.joined(separator: ", "))]
        Select matching items from the list above for the 'tags' field.
        If none match, leave it blank.
        """
    }
    
    // MARK: - List Prompt Builder
    
    private static func buildListPrompt(calendars: [ListInfo], reminders: [ListInfo]) -> String {
        var lines: [String] = []
        
        if !calendars.isEmpty {
            lines.append("Calendar Lists (for type: \"event\" or \"all-day\"):")
            for cal in calendars {
                let desc = cal.prompt.map { ": \($0)" } ?? ""
                lines.append("- \"\(cal.name)\"\(desc)")
            }
        }
        
        if !reminders.isEmpty {
            lines.append("Reminder Lists (for type: \"reminder\"):")
            for rem in reminders {
                let desc = rem.prompt.map { ": \($0)" } ?? ""
                lines.append("- \"\(rem.name)\"\(desc)")
            }
        }
        
        lines.append("Select a matching list from the choices above for the 'list' field. If none match, leave it blank.")
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - User Prompt Construction
    
    /// 专门负责构建发送给 LLM 的用户侧消息
    /// 将 OCR 结果和用户输入合并的逻辑封装在此
    static func buildUserPrompt(
        originalText: String,
        ocrResults: [Int: String]
    ) -> String {
        
        // 1. 格式化 OCR 文本（排序保证顺序一致性）
        let sortedKeys = ocrResults.keys.sorted()
        let formattedOcrText = sortedKeys.compactMap { index -> String? in
            guard let text = ocrResults[index],
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return "[Image \(index + 1)]:\n\(text)"
        }.joined(separator: "\n\n")
        
        // 2. 组合最终 Prompt
        // 所有的 Prompt 格式变动只在这里修改
        return """
            [OCR Result]:
            \(formattedOcrText.isEmpty ? "empty" : formattedOcrText)
            
            [User Input]:
            \(originalText)
            """
    }
    
    // MARK: - Private Helpers
    private static func generateCalendarString(startingFrom startDate: Date) -> String {
        let calendar = Calendar.current
        
        guard let startPoint = calendar.date(byAdding: .day, value: -15, to: startDate) else {
            return "日期计算错误"
        }
        
        let days = sequence(first: startPoint) {
            calendar.date(byAdding: .day, value: 1, to: $0)
        }.prefix(31)
        
        let lines = days.enumerated().map { index, date in
            let dateStr = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            let weekStr = date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "zh_CN")))
            let suffix = (index == 15) ? "(current request)" : ""
            return "\(dateStr) \(weekStr)\(suffix)"
        }
        
        return lines.joined(separator: "\n")
    }

}
