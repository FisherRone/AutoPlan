//
//  EventService+DataReader.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/21.
//

import EventKit

// MARK: - 日历数据读取

extension EventService {

    // MARK: - Public API

    /// 提取指定时间段内的所有日历事件（含全天日程），按开始时间排序
    func fetchEvents(from start: Date, to end: Date) async throws -> [EventEntry] {
        try await requestPermissions()
        let predicate = eventStoreForCreation.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStoreForCreation.events(matching: predicate)
        return events.sorted { $0.startDate < $1.startDate }.map { makeEntry(from: $0) }
    }

    /// 提取指定时间段内完成的提醒事项
    func fetchCompletedReminders(from start: Date, to end: Date) async throws -> [EventEntry] {
        try await requestPermissions()
        let predicate = eventStoreForCreation.predicateForCompletedReminders(
            withCompletionDateStarting: start, ending: end, calendars: nil
        )
        return await fetchReminders(with: predicate)
    }

    /// 提取指定时间段内截止的提醒事项（未完成）
    func fetchDueReminders(from start: Date, to end: Date) async throws -> [EventEntry] {
        try await requestPermissions()
        let predicate = eventStoreForCreation.predicateForIncompleteReminders(
            withDueDateStarting: start, ending: end, calendars: nil
        )
        return await fetchReminders(with: predicate)
    }

    /// 提取未完成且未指定截止时间的提醒事项
    func fetchUntimedReminders() async throws -> [EventEntry] {
        try await requestPermissions()
        // predicateForIncompleteReminders 传 nil 范围获取所有未完成项，再筛选无 dueDate 的
        let predicate = eventStoreForCreation.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil
        )
        let all = await fetchReminders(with: predicate)
        return all.filter { $0.dueDate == nil }
    }

    // MARK: - Private Helpers

    /// 用 predicate 异步获取提醒事项并转换为 EventEntry
    private func fetchReminders(with predicate: NSPredicate) async -> [EventEntry] {
        await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let entries = (reminders ?? []).map(self.makeEntry)
                continuation.resume(returning: entries)
            }
        }
    }

    nonisolated private func makeEntry(from event: EKEvent) -> EventEntry {
        EventEntry(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "",
            type: event.isAllDay ? .allDay : .event,
            isAllDayReminder: false,
            startTime: event.startDate,
            endTime: event.endDate,
            dueDate: nil,
            completionDate: nil,
            isCompleted: false,
            recurrenceRule: event.recurrenceRules?.first?.description,
            listName: event.calendar?.title ?? "",
            listID: event.calendar?.calendarIdentifier ?? "",
            listColorHex: event.calendar?.cgColor?.toHex() ?? "#000000",
            notes: event.notes,
            location: event.location,
            url: event.url?.absoluteString
        )
    }

    nonisolated private func makeEntry(from reminder: EKReminder) -> EventEntry {
        // 全天提醒事项：dueDateComponents 没有 hour/minute/second
        let isAllDay = {
            guard let dc = reminder.dueDateComponents else { return false }
            return dc.hour == nil && dc.minute == nil && dc.second == nil
        }()
        return EventEntry(
            id: reminder.calendarItemIdentifier ?? UUID().uuidString,
            title: reminder.title ?? "",
            type: .reminder,
            isAllDayReminder: isAllDay,
            startTime: reminder.startDateComponents?.date,
            endTime: nil,
            dueDate: reminder.dueDateComponents?.date,
            completionDate: reminder.completionDate,
            isCompleted: reminder.isCompleted,
            recurrenceRule: reminder.recurrenceRules?.first?.description,
            listName: reminder.calendar?.title ?? "",
            listID: reminder.calendar?.calendarIdentifier ?? "",
            listColorHex: reminder.calendar?.cgColor?.toHex() ?? "#000000",
            notes: reminder.notes,
            location: reminder.location,
            url: reminder.url?.absoluteString
        )
    }
}
