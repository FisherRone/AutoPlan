//
//  WeeklyCalendarMarkdown.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/21.
//

import Foundation

/// 将 [EventEntry] 转为"本周日历" Markdown 文本
public enum WeeklyCalendarMarkdown {

    // MARK: - Public

    /// 生成"本周日历"部分
    /// - Parameters:
    ///   - entries: 本周所有事件（已按列表过滤）
    ///   - weekStart: 周一（或周日）的起始日期
    ///   - firstWeekday: 1=Sunday, 2=Monday
    /// - Returns: Markdown 字符串（不含 # 本周日历 标题，由调用方控制）
    public static func generate(entries: [EventEntry], weekStart: Date, firstWeekday: Int = 2) -> String {
        let cal = Calendar.current
        let weekdayNames = firstWeekday == 2
            ? ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
            : ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

        var lines: [String] = []

        for dayOffset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let dayEnd = cal.date(byAdding: .day, value: 1, to: day)!

            let dayEntries = entries.filter { entry in
                belongsTo(entry: entry, on: day, dayEnd: dayEnd, calendar: cal)
            }

            let sorted = sortEntries(dayEntries, calendar: cal)

            let dateStr = day.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            lines.append("### \(dateStr) \(weekdayNames[dayOffset])")

            var prevWasAllDay = false
            for entry in sorted {
                let isAllDay = (entry.type == .allDay) || (entry.type == .reminder && entry.isAllDayReminder)
                // 全天和非全天之间加空行
                if prevWasAllDay && !isAllDay {
                    lines.append("")
                }
                prevWasAllDay = isAllDay

                lines.append(formatEntry(entry, isAllDay: isAllDay, calendar: cal))
            }

            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    /// 生成任意日期范围的日历 Markdown
    /// - Parameters:
    ///   - entries: 事件列表（已按列表过滤）
    ///   - startDate: 起始日期
    ///   - endDate: 结束日期（不含）
    /// - Returns: Markdown 字符串
    public static func generate(entries: [EventEntry], from startDate: Date, to endDate: Date) -> String {
        let cal = Calendar.current
        let weekdaySymbols = cal.weekdaySymbols  // ["周日", "周一", ...] 取决于 locale

        var lines: [String] = []
        var current = cal.startOfDay(for: startDate)

        while current < endDate {
            let dayEnd = cal.date(byAdding: .day, value: 1, to: current)!

            let dayEntries = entries.filter { entry in
                belongsTo(entry: entry, on: current, dayEnd: dayEnd, calendar: cal)
            }

            let sorted = sortEntries(dayEntries, calendar: cal)

            let dateStr = current.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            let weekdayIndex = cal.component(.weekday, from: current) - 1
            let weekdayName = weekdaySymbols[weekdayIndex]
            lines.append("### \(dateStr) \(weekdayName)")

            var prevWasAllDay = false
            for entry in sorted {
                let isAllDay = (entry.type == .allDay) || (entry.type == .reminder && entry.isAllDayReminder)
                if prevWasAllDay && !isAllDay {
                    lines.append("")
                }
                prevWasAllDay = isAllDay

                lines.append(formatEntry(entry, isAllDay: isAllDay, calendar: cal))
            }

            lines.append("")
            current = dayEnd
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 判断归属

    /// 判断 entry 是否属于某一天
    private static func belongsTo(entry: EventEntry, on day: Date, dayEnd: Date, calendar: Calendar) -> Bool {
        switch entry.type {
        case .event, .allDay:
            // 日程：开始时间在当天范围内
            // 跨天全天事件：开始时间 <= day 且结束时间 > day
            guard let start = entry.startTime else { return false }
            if entry.type == .allDay {
                // 全天事件可能跨天：只要和当天有交集
                // start == end 视为单天全天事件，归属 start 所在的那天
                let end = entry.endTime ?? start
                if start == end {
                    return start >= day && start < dayEnd
                }
                return start < dayEnd && end > day
            } else {
                return start >= day && start < dayEnd
            }
        case .reminder:
            if entry.isCompleted, let completion = entry.completionDate {
                // 已完成：按完成时间归属
                return completion >= day && completion < dayEnd
            } else if let due = entry.dueDate {
                // 未完成：按截止时间归属
                return due >= day && due < dayEnd
            } else {
                // 无截止时间的提醒事项不出现在日历中
                return false
            }
        }
    }

    // MARK: - 排序

    /// 排序规则：全天在前，然后按排序时间升序
    /// 排序时间：event 的结束时间、已完成 reminder 的完成时间、未完成 reminder 的截止时间
    private static func sortEntries(_ entries: [EventEntry], calendar: Calendar) -> [EventEntry] {
        entries.sorted { a, b in
            let aAllDay = (a.type == .allDay) || (a.type == .reminder && a.isAllDayReminder)
            let bAllDay = (b.type == .allDay) || (b.type == .reminder && b.isAllDayReminder)

            if aAllDay != bAllDay { return aAllDay }

            return sortOrderTime(for: a) < sortOrderTime(for: b)
        }
    }

    private static func sortOrderTime(for entry: EventEntry) -> Date {
        switch entry.type {
        case .event, .allDay:
            return entry.endTime ?? entry.startTime ?? .distantPast
        case .reminder:
            if entry.isCompleted, let completion = entry.completionDate {
                return completion
            }
            return entry.dueDate ?? .distantPast
        }
    }

    // MARK: - 格式化

    private static func formatEntry(_ entry: EventEntry, isAllDay: Bool, calendar: Calendar) -> String {
        let timePrefix: String
        if isAllDay {
            timePrefix = ""
        } else {
            timePrefix = formatTimePrefix(entry, calendar: calendar)
        }

        let checkbox: String
        if entry.type == .reminder {
            checkbox = entry.isCompleted ? "[x] " : "[ ] "
        } else {
            checkbox = ""
        }

        var parts = [String]()

        // title
        var title = entry.title
        if !timePrefix.isEmpty {
            title = timePrefix + " " + title
        }
        parts.append(checkbox + title)

        // #listname
        if !entry.listName.isEmpty {
            parts.append("#\(entry.listName)")
        }

        // [link](url)
        if let url = entry.url, !url.isEmpty {
            parts.append("[link](\(url))")
        }

        // 📍location
        if let location = entry.location, !location.isEmpty {
            parts.append("📍\(location)")
        }

        let mainLine = "- " + parts.joined(separator: " ")

        // notes
        var result = mainLine
        if let notes = entry.notes, !notes.isEmpty {
            for line in notes.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    result += "\n    - \(trimmed)"
                }
            }
        }

        return result
    }

    private static func formatTimePrefix(_ entry: EventEntry, calendar: Calendar) -> String {
        switch entry.type {
        case .event:
            let start = entry.startTime.map { formatHHmm($0, calendar: calendar) } ?? ""
            let end = entry.endTime.map { formatHHmm($0, calendar: calendar) } ?? ""
            if !start.isEmpty && !end.isEmpty {
                return "\(start) - \(end)"
            } else if !start.isEmpty {
                return start
            }
            return ""
        case .reminder:
            if entry.isAllDayReminder { return "" }
            if entry.isCompleted, let completion = entry.completionDate {
                return formatHHmm(completion, calendar: calendar)
            }
            if let due = entry.dueDate {
                return formatHHmm(due, calendar: calendar)
            }
            return ""
        case .allDay:
            return ""
        }
    }

    private static func formatHHmm(_ date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }
}
