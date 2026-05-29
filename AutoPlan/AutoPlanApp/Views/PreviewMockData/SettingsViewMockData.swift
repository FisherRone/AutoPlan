//
//  SettingsViewMockData.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/29.
//

// MARK: - Mock List Manager
struct ListMockData {
    let calendarLists = [
        ListInfo(id: "preview-cal-1", name: "工作", colorHex: "007AFF", available: true, source: .calendar, prompt: "工作会议", neglected: false, iconName: "briefcase"),
        ListInfo(id: "preview-cal-2", name: "个人", colorHex: "34C759", available: true, source: .calendar, prompt: nil, neglected: false, iconName: "person"),
        ListInfo(id: "preview-cal-3", name: "个人", colorHex: "FF9500", available: true, source: .calendar, prompt: nil, neglected: false, iconName: "person"),
        ListInfo(id: "preview-cal-4", name: "已归档", colorHex: "8E8E93", available: false, source: .calendar, prompt: nil, neglected: true, iconName: "archivebox"),
    ]
    let reminderLists =  [
        ListInfo(id: "preview-rem-1", name: "购物", colorHex: "FF3B30", available: true, source: .reminders, prompt: nil, neglected: false, iconName: "cart"),
        ListInfo(id: "preview-rem-2", name: "待办", colorHex: "007AFF", available: true, source: .reminders, prompt: nil, neglected: false, iconName: "checklist"),
        ListInfo(id: "preview-rem-3", name: "待办", colorHex: "FF9500", available: true, source: .reminders, prompt: nil, neglected: false, iconName: "checklist"),
        ListInfo(id: "preview-rem-4", name: "已完成", colorHex: "8E8E93", available: false, source: .reminders, prompt: nil, neglected: true, iconName: "checkmark.circle"),
    ]
}


@MainActor
final class MockListManager: ListManaging {
    let calendarLists: [ListInfo]
    let reminderLists: [ListInfo]

    init(calendarLists: [ListInfo] = [], reminderLists: [ListInfo] = []) {
        self.calendarLists = calendarLists
        self.reminderLists = reminderLists
    }

    func fetchLists() async throws -> (calendarLists: [ListInfo], reminderLists: [ListInfo]) {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return (calendarLists, reminderLists)
    }

    func setNeglected(for listID: String, neglected: Bool, source: ListSource) {}
    func updatePrompt(for listID: String, prompt: String, source: ListSource) {}
    func setUserIcon(keyword: String, iconName: String) {}
}
