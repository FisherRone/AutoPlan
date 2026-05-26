import Testing
import Foundation
import AutoPlanCore

struct ReportWriterFilterTests {

    /// 按列表 ID 过滤：只保留匹配的日程
    @Test func filterEventsByListID() {
        let events = [
            EventEntry(id: "1", title: "工作日程", type: .event, listName: "工作", listID: "cal-work"),
            EventEntry(id: "2", title: "个人日程", type: .event, listName: "个人", listID: "cal-personal"),
            EventEntry(id: "3", title: "假期", type: .allDay, listName: "假期", listID: "cal-holiday"),
        ]
        let result = ReportWriter.filterByListID(
            events: events,
            completedReminders: [],
            dueReminders: [],
            calendarIDs: ["cal-work", "cal-holiday"],
            reminderIDs: []
        )
        #expect(result.count == 2)
        #expect(result.contains { $0.title == "工作日程" })
        #expect(result.contains { $0.title == "假期" })
        #expect(!result.contains { $0.title == "个人日程" })
    }

    /// 按列表 ID 过滤：只保留匹配的提醒事项
    @Test func filterRemindersByListID() {
        let completed = [
            EventEntry(id: "1", title: "已完成A", type: .reminder, isCompleted: true, listName: "工作", listID: "rem-work"),
            EventEntry(id: "2", title: "已完成B", type: .reminder, isCompleted: true, listName: "个人", listID: "rem-personal"),
        ]
        let due = [
            EventEntry(id: "3", title: "待办A", type: .reminder, listName: "工作", listID: "rem-work"),
            EventEntry(id: "4", title: "待办C", type: .reminder, listName: "购物", listID: "rem-shopping"),
        ]
        let result = ReportWriter.filterByListID(
            events: [],
            completedReminders: completed,
            dueReminders: due,
            calendarIDs: [],
            reminderIDs: ["rem-work"]
        )
        #expect(result.count == 2)
        #expect(result.contains { $0.title == "已完成A" })
        #expect(result.contains { $0.title == "待办A" })
    }

    /// 空列表 ID → 全部过滤掉
    @Test func emptyIDsFiltersAll() {
        let events = [EventEntry(id: "1", title: "E1", type: .event, listName: "工作", listID: "cal1")]
        let result = ReportWriter.filterByListID(
            events: events,
            completedReminders: [],
            dueReminders: [],
            calendarIDs: [],
            reminderIDs: []
        )
        #expect(result.isEmpty)
    }

    /// 不存在的 ID → 全部过滤掉
    @Test func nonExistentIDFiltersAll() {
        let events = [EventEntry(id: "1", title: "E1", type: .event, listName: "工作", listID: "cal1")]
        let result = ReportWriter.filterByListID(
            events: events,
            completedReminders: [],
            dueReminders: [],
            calendarIDs: ["cal-nonexistent"],
            reminderIDs: []
        )
        #expect(result.isEmpty)
    }

    /// 混合过滤：日程和提醒事项分别按各自 ID 过滤
    @Test func mixedFiltering() {
        let events = [
            EventEntry(id: "1", title: "E1", type: .event, listName: "A", listID: "cal-a"),
            EventEntry(id: "2", title: "E2", type: .event, listName: "B", listID: "cal-b"),
        ]
        let completed = [
            EventEntry(id: "3", title: "R1", type: .reminder, listName: "A", listID: "rem-a"),
        ]
        let due = [
            EventEntry(id: "4", title: "R2", type: .reminder, listName: "B", listID: "rem-b"),
        ]
        let result = ReportWriter.filterByListID(
            events: events,
            completedReminders: completed,
            dueReminders: due,
            calendarIDs: ["cal-a"],
            reminderIDs: ["rem-b"]
        )
        #expect(result.count == 2)
        #expect(result.contains { $0.title == "E1" })
        #expect(result.contains { $0.title == "R2" })
    }
}
