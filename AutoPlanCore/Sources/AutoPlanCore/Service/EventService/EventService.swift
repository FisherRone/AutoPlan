//
//  EventService.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/24.
//

import SwiftUI
import EventKit
import OSLog

// MARK: - EventStore 协议（用于测试注入）

public protocol EventStoreProtocol: Sendable {
    func requestFullAccessToEvents() async throws -> Bool
    func requestFullAccessToReminders() async throws -> Bool
    func requestAccess(to entityType: EKEntityType) async throws -> Bool
    func defaultCalendarForNewEvents() -> EKCalendar?
    func defaultCalendarForNewReminders() -> EKCalendar?
    func calendars(for entityType: EKEntityType) -> [EKCalendar]
    func calendar(withIdentifier identifier: String) -> EKCalendar?
    func sources() -> [EKSource]
    func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws
    func save(_ event: EKEvent, span: EKSpan) throws
    func save(_ reminder: EKReminder, commit: Bool) throws
}

extension EKEventStore: EventStoreProtocol {
    public func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        if entityType == EKEntityType.event {
            return try await withCheckedThrowingContinuation { continuation in
                requestFullAccessToEvents() { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
        else {
            return try await withCheckedThrowingContinuation { continuation in
                requestFullAccessToReminders() { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    public func sources() -> [EKSource] {
        return self.sources
    }

    public func defaultCalendarForNewEvents() -> EKCalendar? {
        return self.defaultCalendarForNewEvents
    }
}

// MARK: - 错误定义

enum EventServiceError: Error, LocalizedError {
    case eventPermissionDenied
    case reminderPermissionDenied
    case eventPermissionRestricted
    case reminderPermissionRestricted
    case calendarAccessFailed(Error)
    case saveFailed(Error)
    case calendarCreationFailed(Error)
    case sourceNotFound // 无法找到创建日历所需的账户源（如 iCloud 或 本地）
    
    var errorDescription: String? {
        switch self {
        case .eventPermissionDenied:
            return "没有日历访问权限，请在设置中开启。"
        case .reminderPermissionDenied:
            return "没有提醒事项访问权限，请在设置中开启。"
        case .eventPermissionRestricted:
            return "日历访问受限（可能是家长控制或企业配置）。"
        case .reminderPermissionRestricted:
            return "提醒事项访问受限。"
        case .calendarAccessFailed(let error):
            return "读取日历数据失败: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "保存事项失败: \(error.localizedDescription)"
        case .calendarCreationFailed(let error):
            return "无法创建自动计划日历: \(error.localizedDescription)"
        case .sourceNotFound:
            return "无法找到可用的日历账户源（如 iCloud），无法创建新日历。"
        }
    }
}


@MainActor
final class EventService {
    static let shared = EventService()
    internal let eventStore = EKEventStore()
    private let store: any EventStoreProtocol
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "App", category: "EventService")
    private var appDefaultEventListID: String? {
        get { UserDefaults.standard.string(forKey: "AppDefaultEventListID") }
        set { UserDefaults.standard.set(newValue, forKey: "AppDefaultEventListID") }
    }

    private var appDefaultReminderListID: String? {
        get { UserDefaults.standard.string(forKey: "AppDefaultReminderListID") }
        set { UserDefaults.standard.set(newValue, forKey: "AppDefaultReminderListID") }
    }

    let eventStoreForCreation: EKEventStore

    init(store: any EventStoreProtocol = EKEventStore()) {
        self.store = store
        self.eventStoreForCreation = (store as? EKEventStore) ?? EKEventStore()
    }

    /// 测试专用初始化器，允许注入统一的 EKEventStore 避免跨 store 对象绑定导致 abort
    init(store: any EventStoreProtocol, eventStoreForCreation: EKEventStore) {
        self.store = store
        self.eventStoreForCreation = eventStoreForCreation
    }
    
    
    
    // MARK: - 保存数据 (Save)
    
    /// 将最终确认的 EventItem 写入系统，返回系统日历标识符
    @discardableResult
    func saveEventItem(_ item: EventItem) async throws -> String? {
        try await requestPermissions()
        
        do {
            var identifier: String?
            switch item.type {
            case .event, .allDay:
                identifier = try await saveToCalendar(item)
            case .reminder:
                identifier = try await saveToReminders(item)
            }
            logger.info("🚀 Saved successfully: \(item.title, privacy: .public)")
            return identifier
        } catch {
            logger.error("❌ Save failed: \(error.localizedDescription)")
            throw EventServiceError.saveFailed(error)
        }
    }
    
    // MARK: - request permissions
    
    func requestPermissions() async throws {
        if #available(iOS 17.0, macOS 14.0, *) {
            // iOS 17+ 区分 WriteOnly 和 FullAccess，这里为了读取列表，通常需要 FullAccess
            // 如果只需要写，不需要读列表，可以申请 .writeOnly
            let eventStatus = EKEventStore.authorizationStatus(for: .event)
            if eventStatus == .notDetermined {
                let granted = try await store.requestFullAccessToEvents()
                if !granted { throw EventServiceError.eventPermissionDenied }
            } else if eventStatus == .denied {
                throw EventServiceError.eventPermissionDenied
            }
            
            let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
            if reminderStatus == .notDetermined {
                let granted = try await store.requestFullAccessToReminders()
                if !granted { throw EventServiceError.reminderPermissionDenied }
            } else if reminderStatus == .denied {
                throw EventServiceError.reminderPermissionDenied
            }
            
        } else {
            // 旧版本 API
            let eventGranted = try await store.requestAccess(to: .event)
            if !eventGranted { throw EventServiceError.eventPermissionDenied }
            
            let reminderGranted = try await store.requestAccess(to: .reminder)
            if !reminderGranted { throw EventServiceError.reminderPermissionDenied }
        }
    }
    

    
    
    // MARK: - get default list
    
    /// 逻辑：系统默认 -> 寻找 AppDefaultList -> 初始化 AutoPlan
    private func getOrSetupDefaultListInfo(for type: EKEntityType) async throws -> ListInfo {

        // 1. 尝试获取系统默认日历
        // 注意：defaultCalendarForNewEvents 可能会返回 nil (极其罕见，但 API 允许)
        let systemDefault: EKCalendar? = (type == .event)
        ? store.defaultCalendarForNewEvents()
        : store.defaultCalendarForNewReminders()
        
        if let systemCal = systemDefault {
            return createListInfo(from: systemCal, type: type)
        }
        
        // 2. 系统没有默认日历 (走到这里说明情况很特殊)，检查 App 缓存的 ID
        let cachedID = (type == .event) ? appDefaultEventListID : appDefaultReminderListID
        
        if let id = cachedID, let cachedCal = store.calendar(withIdentifier: id) {
            logger.info("🔄 Recovered AppDefault calendar: \(cachedCal.title)")
            return createListInfo(from: cachedCal, type: type)
        }
        
        // 3. 既没有系统默认，缓存的也找不到 (可能被用户删了)，初始化 "AutoPlan"
        logger.notice("🆕 Creating new 'AutoPlan' calendar for \(type == .event ? "Events" : "Reminders")")
        let newCal = try await createAutoPlanCalendar(for: type)
        
        // 4. 更新缓存
        if type == .event {
            appDefaultEventListID = newCal.calendarIdentifier
        } else {
            appDefaultReminderListID = newCal.calendarIdentifier
        }
        
        return createListInfo(from: newCal, type: type)
    }
    
    private func createAutoPlanCalendar(for type: EKEntityType) async throws -> EKCalendar {
        let newCalendar = EKCalendar(for: type, eventStore: eventStoreForCreation)
        newCalendar.title = "AutoPlan"

        // 设置颜色 (蓝色)
        newCalendar.cgColor = CGColor(srgbRed: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)

        let defaultCal = store.defaultCalendarForNewEvents()
        let icloudSource = store.sources().first(where: { $0.sourceType == .calDAV && $0.title.contains("iCloud") })
        let localSource = store.sources().first(where: { $0.sourceType == .local })
        let bestSource = defaultCal?.source ?? icloudSource ?? localSource
        
        guard let source = bestSource else {
            throw EventServiceError.sourceNotFound
        }
        
        newCalendar.source = source
        
        do {
            try store.saveCalendar(newCalendar, commit: true)
            return newCalendar
        } catch {
            throw EventServiceError.calendarCreationFailed(error)
        }
    }
    
    
    private func getDefaultListInfo(for type: EKEntityType) -> ListInfo? {
        let calendar: EKCalendar?
        if type == .event {
            calendar = store.defaultCalendarForNewEvents()
        } else {
            calendar = store.defaultCalendarForNewReminders()
        }
        
        guard let cal = calendar else { return nil }
        return createListInfo(from: cal, type: type)
    }
    
    private func createListInfo(from calendar: EKCalendar, type: EKEntityType) -> ListInfo {
            let source: ListSource = (type == .reminder) ? .reminders : .calendar
            return ListInfo(
                id: calendar.calendarIdentifier,
                name: calendar.title,
                colorHex: calendar.cgColor?.toHex() ?? "#000000",
                available: true,
                source: source,
                prompt: nil,
                iconName: ListInfo.iconName(for: calendar.title, source: source)
            )
        }
    
    // MARK: - save to calender & reminder
    
    @discardableResult
    private func saveToCalendar(_ item: EventItem) async throws -> String? {
        let ekEvent = EKEvent(eventStore: eventStoreForCreation)
        ekEvent.title = item.title
        ekEvent.notes = item.notes
        ekEvent.startDate = item.startTime
        ekEvent.endDate = item.endTime
        ekEvent.isAllDay = (item.type == .allDay)
        ekEvent.location = item.location
        
        if let urlStr = item.url, let url = URL(string: urlStr) {
            ekEvent.url = url
        }
        
        // 设置日历
        if let calendarID = item.listInfo?.id, let calendar = store.calendar(withIdentifier: calendarID) {
            ekEvent.calendar = calendar
        } else {
            // 极端的兜底：如果 Item 里的 listInfo ID 无效了，重新获取一次默认
            let fallback = try await getOrSetupDefaultListInfo(for: .event)
            if let cal = store.calendar(withIdentifier: fallback.id) {
                ekEvent.calendar = cal
            }
        }
        
        if let alarmDate = item.alarmTime {
            ekEvent.addAlarm(EKAlarm(absoluteDate: alarmDate))
        }
        
        try store.save(ekEvent, span: .thisEvent)
        return ekEvent.eventIdentifier
    }
    
    @discardableResult
    private func saveToReminders(_ item: EventItem) async throws -> String? {
        let reminder = EKReminder(eventStore: eventStoreForCreation)
        reminder.title = item.title
        reminder.notes = item.notes
        
        if let calendarID = item.listInfo?.id, let calendar = store.calendar(withIdentifier: calendarID) {
            reminder.calendar = calendar
        } else {
            let fallback = try await getOrSetupDefaultListInfo(for: .reminder)
            if let cal = store.calendar(withIdentifier: fallback.id) {
                reminder.calendar = cal
            }
        }
        
        // 设置日期组件
        if let date = item.reminderTime ?? item.startTime {
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            // 当时间部分为 0 时（即只有日期没有具体时间），设置为全天提醒事项
            if comps.hour == 0 && comps.minute == 0 {
                reminder.dueDateComponents = cal.dateComponents([.year, .month, .day], from: date)
            } else {
                reminder.dueDateComponents = comps
            }
        }
        
        if let alarmDate = item.alarmTime {
            reminder.addAlarm(EKAlarm(absoluteDate: alarmDate))
        }
        
        try store.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }
    
    // MARK: - 获取可写入的日历列表
    
    /// 获取所有可写入的日历/列表
    /// - Parameter type: 事件类型
    /// - Returns: 可写入的日历信息列表
    func getWritableCalendars(for type: EventType) async throws -> [ListInfo] {
        try await requestPermissions()
        
        let entityType: EKEntityType = (type == .reminder) ? .reminder : .event
        let calendars = store.calendars(for: entityType)
        
        let writableCalendars = calendars.filter { $0.allowsContentModifications }
        
        return writableCalendars.map { createListInfo(from: $0, type: entityType) }
    }
}
