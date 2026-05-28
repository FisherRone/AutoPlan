import Testing
import Foundation
import AutoPlanCore

struct WeeklyCalendarMarkdownTests {

    // 2026-05-18 是周一
    private let weekStart = date(2026, 5, 18)

    /// 空列表 → 每天只有标题
    @Test func emptyEntries() {
        let md = WeeklyCalendarMarkdown.generate(entries: [], weekStart: weekStart, firstWeekday: 2)
        #expect(md.contains("### 2026-05-18 周一"))
        #expect(md.contains("### 2026-05-24 周日"))
        #expect(!md.contains("- "))
    }

    /// 普通日程：显示时间范围
    @Test func timedEvent() {
        let entries = [
            EventEntry(
                id: "1", title: "站会", type: .event,
                startTime: date(2026, 5, 18, 9, 0),
                endTime: date(2026, 5, 18, 9, 30),
                listName: "工作"
            ),
        ]
        let md = WeeklyCalendarMarkdown.generate(entries: entries, weekStart: weekStart, firstWeekday: 2)
        #expect(md.contains("09:00 - 09:30"))
        #expect(md.contains("站会"))
        #expect(md.contains("#工作"))
    }

    /// 全天日程：无时间前缀
    @Test func allDayEvent() {
        let entries = [
            EventEntry(
                id: "1", title: "出差", type: .allDay,
                startTime: date(2026, 5, 19),
                endTime: date(2026, 5, 21),
                listName: "工作"
            ),
        ]
        let md = WeeklyCalendarMarkdown.generate(entries: entries, weekStart: weekStart, firstWeekday: 2)
        #expect(!md.contains("09:00"))
        #expect(md.contains("出差"))
        // 跨天全天事件出现在多个日期
        let tuesdaySection = md.components(separatedBy: "### 2026-05-19 周二").last?.components(separatedBy: "### 2026-05-20 周三").first ?? ""
        #expect(tuesdaySection.contains("出差"))
    }

    /// 全天提醒事项：无时间前缀，有 checkbox
    @Test func allDayReminder() {
        let entries = [
            EventEntry(
                id: "1", title: "交报告", type: .reminder,
                isAllDayReminder: true,
                dueDate: date(2026, 5, 18),
                listName: "工作"
            ),
        ]
        let md = WeeklyCalendarMarkdown.generate(entries: entries, weekStart: weekStart, firstWeekday: 2)
        #expect(md.contains("[ ] 交报告"))
        #expect(!md.contains("00:00"))
    }

    /// 定时提醒事项：显示时间，有 checkbox
    @Test func timedReminder() {
        let entries = [
            EventEntry(
                id: "1", title: "吃药", type: .reminder,
                dueDate: date(2026, 5, 18, 8, 0),
                listName: "生活"
            ),
        ]
        let md = WeeklyCalendarMarkdown.generate(entries: entries, weekStart: weekStart, firstWeekday: 2)
        #expect(md.contains("[ ] 08:00 吃药"))
    }

    /// 已完成提醒事项：按完成时间归属，checkbox 打勾
    @Test func completedReminder() {
        let entries = [
            EventEntry(
                id: "1", title: "买菜", type: .reminder,
                dueDate: date(2026, 5, 17),
                completionDate: date(2026, 5, 18, 12, 0),
                isCompleted: true,
                listName: "生活"
            ),
        ]
        let md = WeeklyCalendarMarkdown.generate(entries: entries, weekStart: weekStart, firstWeekday: 2)
        #expect(md.contains("[x] 12:00 买菜"))
        let mondaySection = md.components(separatedBy: "### 2026-05-18 周一").last?.components(separatedBy: "### 2026-05-19 周二").first ?? ""
        #expect(mondaySection.contains("买菜"))
    }

    /// 全天事件排在定时事件前面
    @Test func allDayBeforeTimed() {
        let entries = [
            EventEntry(
                id: "1", title: "站会", type: .event,
                startTime: date(2026, 5, 18, 9, 0),
                endTime: date(2026, 5, 18, 9, 30),
                listName: "工作"
            ),
            EventEntry(
                id: "2", title: "出差", type: .allDay,
                startTime: date(2026, 5, 18),
                endTime: date(2026, 5, 18),
                listName: "工作"
            ),
        ]
        let md = WeeklyCalendarMarkdown.generate(entries: entries, weekStart: weekStart, firstWeekday: 2)
        let mondaySection = md.components(separatedBy: "### 2026-05-18 周一").last?.components(separatedBy: "### 2026-05-19 周二").first ?? ""
        let allDayRange = mondaySection.range(of: "出差")!
        let timedRange = mondaySection.range(of: "站会")!
        #expect(allDayRange.lowerBound < timedRange.lowerBound)
    }

    /// 周日起始（firstWeekday=1）
    @Test func sundayFirst() {
        let sundayStart = date(2026, 5, 17)
        let entries = [
            EventEntry(
                id: "1", title: "早午餐", type: .event,
                startTime: date(2026, 5, 17, 11, 0),
                endTime: date(2026, 5, 17, 12, 0),
                listName: "生活"
            ),
        ]
        let md = WeeklyCalendarMarkdown.generate(entries: entries, weekStart: sundayStart, firstWeekday: 1)
        #expect(md.contains("### 2026-05-17 周日"))
        #expect(md.contains("### 2026-05-23 周六"))
    }

    /// 无截止时间的提醒事项不出现在日历中
    @Test func untimedReminderExcluded() {
        let entries = [
            EventEntry(id: "1", title: "读书", type: .reminder, listName: "个人"),
        ]
        let md = WeeklyCalendarMarkdown.generate(entries: entries, weekStart: weekStart, firstWeekday: 2)
        #expect(!md.contains("读书"))
    }

    /// 带位置和链接
    @Test func locationAndURL() {
        let entries = [
            EventEntry(
                id: "1", title: "会议", type: .event,
                startTime: date(2026, 5, 18, 14, 0),
                endTime: date(2026, 5, 18, 15, 0),
                listName: "工作",
                location: "3号会议室",
                url: "https://zoom.us/j/123"
            ),
        ]
        let md = WeeklyCalendarMarkdown.generate(entries: entries, weekStart: weekStart, firstWeekday: 2)
        #expect(md.contains("📍3号会议室"))
        #expect(md.contains("[link](https://zoom.us/j/123)"))
    }
}

// MARK: - Test Helpers

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
