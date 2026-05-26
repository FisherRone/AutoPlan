import Testing
import Foundation
import AutoPlanCore

struct WeeklyStatisticsTests {

    /// 空列表 → 0, 0
    @Test func emptyEntries() {
        let stats = WeeklyStatistics.from(entries: [])
        #expect(stats.eventCount == 0)
        #expect(stats.reminderCount == 0)
    }

    /// 纯日程
    @Test func onlyEvents() {
        let entries = [
            EventEntry(id: "1", title: "E1", type: .event, listName: "工作"),
            EventEntry(id: "2", title: "E2", type: .allDay, listName: "工作"),
        ]
        let stats = WeeklyStatistics.from(entries: entries)
        #expect(stats.eventCount == 2)
        #expect(stats.reminderCount == 0)
    }

    /// 纯提醒事项
    @Test func onlyReminders() {
        let entries = [
            EventEntry(id: "1", title: "R1", type: .reminder, listName: "生活"),
            EventEntry(id: "2", title: "R2", type: .reminder, listName: "生活"),
            EventEntry(id: "3", title: "R3", type: .reminder, listName: "生活"),
        ]
        let stats = WeeklyStatistics.from(entries: entries)
        #expect(stats.eventCount == 0)
        #expect(stats.reminderCount == 3)
    }

    /// 混合
    @Test func mixedEntries() {
        let entries = [
            EventEntry(id: "1", title: "E1", type: .event, listName: "工作"),
            EventEntry(id: "2", title: "E2", type: .allDay, listName: "工作"),
            EventEntry(id: "3", title: "R1", type: .reminder, listName: "生活"),
        ]
        let stats = WeeklyStatistics.from(entries: entries)
        #expect(stats.eventCount == 2)
        #expect(stats.reminderCount == 1)
    }

    /// summary 文本格式
    @Test func summaryFormat() {
        let stats = WeeklyStatistics(eventCount: 5, reminderCount: 3)
        #expect(stats.summary == "本周日程数: 5，本周提醒事项数: 3")
    }
}
