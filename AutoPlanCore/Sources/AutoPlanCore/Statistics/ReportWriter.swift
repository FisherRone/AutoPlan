//
//  ReportWriter.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/21.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "AutoPlanCore", category: "ReportWriter")

public enum ReportWriter {

    // MARK: - Public

    /// 生成周报
    /// - Parameters:
    ///   - date: 任意日期，自动计算其所在周
    ///   - config: 列表配置（用于过滤关注的列表）
    /// - Returns: 周报 Markdown 字符串
    @discardableResult
    public static func writeWeeklyReport(date: Date, config: CoreConfiguration) async throws -> String {
        let firstWeekday = UserDefaults.standard.object(forKey: "firstWeekday") as? Int ?? 2
        let (weekStart, weekEnd) = weekRange(for: date, firstWeekday: firstWeekday)

        // 1. 获取关注的列表 ID（优先用 reportFocused 配置，否则用 neglected 过滤）
        let focusedCalendarIDs = focusedListIDs(
            forKey: "reportFocusedEventList",
            allLists: config.userCalendarLists
        )
        let focusedReminderIDs = focusedListIDs(
            forKey: "reportFocusedReminderList",
            allLists: config.userReminderLists
        )

        // 2. 读取数据
        let events = try await EventService.shared.fetchEvents(from: weekStart, to: weekEnd)
        let completedReminders = try await EventService.shared.fetchCompletedReminders(from: weekStart, to: weekEnd)
        let dueReminders = try await EventService.shared.fetchDueReminders(from: weekStart, to: weekEnd)
        let untimedReminders = try await EventService.shared.fetchUntimedReminders()

        // 3. 按关注列表过滤
        let allEntries = filterByListID(
            events: events,
            completedReminders: completedReminders,
            dueReminders: dueReminders,
            calendarIDs: focusedCalendarIDs,
            reminderIDs: focusedReminderIDs
        )

        let untimedFiltered = untimedReminders.filter { focusedReminderIDs.contains($0.listID) }

        // 4. 统计
        let statistics = WeeklyStatistics.from(entries: allEntries)

        // 5. 生成本周日历 Markdown
        let calendarMarkdown = WeeklyCalendarMarkdown.generate(
            entries: allEntries,
            weekStart: weekStart,
            firstWeekday: firstWeekday
        )

        // 6. 未指定时间的提醒事项文本
        let untimedText = formatUntimedReminders(untimedFiltered)

        // 7. 构建提示词
        let timeRangeStr = formatDate(weekStart) + " - " + formatDate(weekEnd.addingTimeInterval(-1))
        let prompt = PromptBuilder.buildWeeklyReportPrompt(
            timeRange: timeRangeStr,
            statistics: statistics,
            calendarMarkdown: calendarMarkdown,
            untimedReminders: untimedText
        )

        // 8. 调用 LLM
        let briefing: String
        do {
            guard let context = resolveRequestContext() else {
                briefing = "（LLM 未配置，跳过简报生成）"
                logger.warning("LLM context 未配置，跳过简报生成")
                return assembleReport(
                    weekStart: weekStart, weekEnd: weekEnd,
                    briefing: briefing, calendarMarkdown: calendarMarkdown
                )
            }
            let raw = try await LLMClient.shared.getResponse(prompt: prompt, context: context)
            briefing = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            briefing = "（简报生成失败：\(error.localizedDescription)）"
            logger.error("周报简报生成失败: \(error.localizedDescription)")
        }

        // 9. 组装完整周报
        let report = assembleReport(
            weekStart: weekStart, weekEnd: weekEnd,
            briefing: briefing, calendarMarkdown: calendarMarkdown
        )

        // 10. 保存文件
        logger.info("🔄 准备调用 saveReport")
        saveReport(report, weekStart: weekStart, entries: allEntries, firstWeekday: firstWeekday, listOrder: focusedCalendarIDs)
        logger.info("✅ saveReport 已返回")

        return report
    }

    // MARK: - Private Helpers

    private static func weekRange(for date: Date, firstWeekday: Int) -> (start: Date, end: Date) {
        var cal = Calendar.current
        cal.firstWeekday = firstWeekday
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: date) else {
            let start = cal.date(from: cal.dateComponents([.year, .weekOfYear], from: date)) ?? date
            return (start, start.addingTimeInterval(7 * 86400))
        }
        return (weekInterval.start, weekInterval.end)
    }

    /// 获取关注的列表 ID：优先用 reportFocused 配置，为空则 fallback 到 neglected 过滤
    private static func focusedListIDs(forKey key: String, allLists: [ListInfo]) -> [String] {
        if let focused = UserDefaults.standard.stringArray(forKey: key), !focused.isEmpty {
            return focused
        }
        return allLists.filter { !$0.neglected }.map(\.id)
    }

    public static func filterByListID(
        events: [EventEntry],
        completedReminders: [EventEntry],
        dueReminders: [EventEntry],
        calendarIDs: [String],
        reminderIDs: [String]
    ) -> [EventEntry] {
        let filteredEvents = events.filter { calendarIDs.contains($0.listID) }
        let filteredCompleted = completedReminders.filter { reminderIDs.contains($0.listID) }
        let filteredDue = dueReminders.filter { reminderIDs.contains($0.listID) }
        return filteredEvents + filteredCompleted + filteredDue
    }

    private static func formatUntimedReminders(_ reminders: [EventEntry]) -> String {
        if reminders.isEmpty { return "（无）" }
        return reminders.map { "- \($0.title) #\($0.listName)\($0.isCompleted ? " ✅" : "")" }.joined(separator: "\n")
    }

    private static func assembleReport(
        weekStart: Date,
        weekEnd: Date,
        briefing: String,
        calendarMarkdown: String
    ) -> String {
        let dateRange = formatDate(weekStart) + "-" + formatDate(weekEnd.addingTimeInterval(-1))
        let dateStr = formatDate(weekStart)
        let pngFilename = "weekly_report_\(dateStr).png"

        return """
        # 周报 [\(dateRange)]

        ## 简报
        ![\(pngFilename)](\(pngFilename))
        \(briefing)

        ## 本周日历
        \(calendarMarkdown)
        """
    }

    private static func saveReport(_ markdown: String, weekStart: Date, entries: [EventEntry], firstWeekday: Int, listOrder: [String]) {
        let dir = reportDirectory()
        logger.info("📁 reportDirectory: \(dir)")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let dateStr = formatDate(weekStart)
        let mdPath = (dir as NSString).appendingPathComponent("weekly_report_\(dateStr).md")

        do {
            try markdown.write(toFile: mdPath, atomically: true, encoding: .utf8)
            logger.info("周报已保存: \(mdPath)")
        } catch {
            logger.error("周报保存失败: \(error.localizedDescription)")
        }

        // 生成图表 PNG（需要在 MainActor 上执行）
        let pngPath = (dir as NSString).appendingPathComponent("weekly_report_\(dateStr).png")
        Task { @MainActor in
            saveChartPNG(entries: entries, to: pngPath, firstWeekday: firstWeekday, listOrder: listOrder)
        }
    }

    @MainActor
    private static func saveChartPNG(entries: [EventEntry], to path: String, firstWeekday: Int, listOrder: [String]) {
        let chart = TimeSheetBar(events: entries, firstWeekday: firstWeekday, listOrder: listOrder)
        guard let pngData = renderViewToPNG(chart, size: CGSize(width: 800, height: 400)) else {
            logger.error("图表 PNG 渲染失败")
            return
        }
        do {
            try pngData.write(to: URL(fileURLWithPath: path))
            logger.info("图表已保存: \(path)")
        } catch {
            logger.error("图表保存失败: \(error.localizedDescription)")
        }
    }

    private static func reportDirectory() -> String {
        // 临时写死为沙盒内路径，避免 sandbox deny 问题
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? "/tmp"
        return (appSupport as NSString).appendingPathComponent("AutoPlan/Reports")
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func resolveRequestContext() -> LLMRequestContext? {
        let selectedModelName = UserDefaults.standard.string(forKey: "weeklyReportModelName") ?? ""
        guard !selectedModelName.isEmpty else { return nil }

        let matchedModel = SystemLLMConfig.models.first { $0.name == selectedModelName }
        guard let model = matchedModel else { return nil }

        let service = LLMService(
            systemProviders: SystemLLMConfig.providers,
            userModels: { [] }
        )
        return service.requestContext(for: model)
    }
}
