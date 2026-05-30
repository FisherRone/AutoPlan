import Foundation

// MARK: - 相对日期解析

/// 解析 LLM 输出的相对日期扩展格式，如 "2026-06-01 +1week sunday 12:00"
/// 格式: YYYY-MM-DD [±Nweek] weekday [HH:MM]
public enum RelativeDateParser {

    /// 英文星期名 -> Calendar.current 的 weekday 值（1=Sunday ... 7=Saturday）
    nonisolated private static let weekdayMap: [String: Int] = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
        "thursday": 5, "friday": 6, "saturday": 7,
        "sun": 1, "mon": 2, "tue": 3, "wed": 4,
        "thu": 5, "fri": 6, "sat": 7
    ]

    // 正则: 基准日期 [±Nweek] 星期 [时间]
    // ±Nweek 部分可选，省略时默认为 0（本周）
    // 示例: "2026-06-01 +1week sunday 12:00"
    //       "2026-06-01 -2week friday"
    //       "2026-06-01 wednesday 08:30"   (省略周偏移 = 本周)
    //       "2026-06-01 +0 week monday 9:00"  (数字和 week 之间有空格)
    nonisolated private static let pattern = #"""
    ^(\d{4}-\d{2}-\d{2})\s+(?:([+-]?\d+)\s*week\s+)?(\w+)\s*(\d{1,2}:\d{2})?$
    """#

    /// 尝试解析相对日期字符串，成功返回 Date，不匹配返回 nil
    /// - Parameters:
    ///   - string: 待解析字符串
    ///   - firstWeekday: 一周的第一天（1=Sunday, 2=Monday），nil 时从 UserDefaults 读取，默认周一
    nonisolated public static func parse(_ string: String, firstWeekday: Int? = nil) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              match.numberOfRanges == 5 else {
            return nil
        }

        // 1. 基准日期
        let baseDateStr = String(string[Range(match.range(at: 1), in: string)!])
        guard let baseDate = Date.parseAbsoluteDate(baseDateStr) else { return nil }

        // 2. 周偏移量（可选，默认为 0）
        let weekOffset: Int
        if match.range(at: 2).location != NSNotFound,
           let weekRange = Range(match.range(at: 2), in: string) {
            weekOffset = Int(String(string[weekRange])) ?? 0
        } else {
            weekOffset = 0
        }

        // 3. 星期几
        let weekdayStr = String(string[Range(match.range(at: 3), in: string)!]).lowercased()
        guard let targetWeekday = weekdayMap[weekdayStr] else { return nil }

        // 4. 时间（可选）
        var hour: Int? = nil
        var minute: Int? = nil
        if match.range(at: 4).location != NSNotFound,
           let timeRange = Range(match.range(at: 4), in: string) {
            let timeStr = String(string[timeRange])
            let parts = timeStr.split(separator: ":")
            if parts.count == 2,
               let h = Int(parts[0]),
               let m = Int(parts[1]) {
                hour = h
                minute = m
            }
        }

        // 5. 计算目标日期
        let calendar = Calendar.current
        let firstWeekday = firstWeekday ?? UserDefaults.standard.object(forKey: "firstWeekday") as? Int ?? 2 // 默认周一

        // 计算基准日所在周的起始日
        let baseWeekday = calendar.component(.weekday, from: baseDate)
        // 基准日到周起始日的偏移天数
        let daysToWeekStart = (baseWeekday - firstWeekday + 7) % 7
        guard let weekStartDate = calendar.date(byAdding: .day, value: -daysToWeekStart, to: calendar.startOfDay(for: baseDate)) else {
            return nil
        }

        // 目标周起始日 = 本周起始日 + weekOffset * 7天
        guard let targetWeekStart = calendar.date(byAdding: .day, value: weekOffset * 7, to: weekStartDate) else {
            return nil
        }

        // 目标星期几在目标周内的偏移天数
        let daysFromWeekStart = (targetWeekday - firstWeekday + 7) % 7
        guard let targetDate = calendar.date(byAdding: .day, value: daysFromWeekStart, to: targetWeekStart) else {
            return nil
        }

        // 6. 设置时间
        if let h = hour, let m = minute {
            return calendar.date(bySettingHour: h, minute: m, second: 0, of: targetDate)
        } else {
            // 无时间部分，返回当天起始
            return calendar.startOfDay(for: targetDate)
        }
    }
}

// MARK: - Date 解析扩展

extension Date {
    private static nonisolated let sharedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    public nonisolated static func parse(_ string: String?) -> Date? {
        guard let string = string, !string.isEmpty else { return nil }

        // 优先尝试相对日期格式
        if let relativeDate = RelativeDateParser.parse(string) {
            return relativeDate
        }

        let strategies = [
            "yyyy-MM-dd HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm", "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd",
            "MM-dd HH:mm", "MM-dd HH:mm:ss", "MM-dd",
            "MM/dd HH:mm", "MM/dd HH:mm:ss", "MM/dd"
        ]

        for format in strategies {
            sharedFormatter.dateFormat = format
            if let date = sharedFormatter.date(from: string) {
                if !format.contains("yyyy") {
                    return date.fixedToCurrentYear()
                }
                return date
            }
        }

        return ISO8601DateFormatter().date(from: string)
    }

    /// 仅解析 YYYY-MM-DD 绝对日期（供 RelativeDateParser 内部使用）
    nonisolated static func parseAbsoluteDate(_ string: String) -> Date? {
        sharedFormatter.dateFormat = "yyyy-MM-dd"
        return sharedFormatter.date(from: string)
    }

    private nonisolated func fixedToCurrentYear() -> Date {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        var components = calendar.dateComponents([.month, .day, .hour, .minute], from: self)
        components.year = currentYear

        return calendar.date(from: components) ?? self
    }
}
