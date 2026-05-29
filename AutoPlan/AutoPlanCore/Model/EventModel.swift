//
//  EventModel.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/24.
//

import Foundation
import EventKit
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - Definitions
/// 计划类型枚举
public enum EventType: String, Codable, Sendable {
    case event = "event"
    case allDay = "all-day"
    case reminder = "reminder"

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self).lowercased()
        
        // 2. 匹配不同的拼写可能性
        switch rawString {
        case "all-day", "allday", "all_day":
            self = .allDay
        case "remind", "reminder":
            self = .reminder
        default:
            self = .event
        }
    }
}

public enum EventStatus: String, Codable, Sendable {
    case pending = "pending"
    case saved = "saved"
    case rejected = "rejected"
}

public enum ListSource: String, Codable, Sendable {
    case calendar
    case reminders
}

public struct ListInfo: Codable, Hashable, Identifiable, Sendable {
    public let id: String // 系统 id，用于保存至日历或提醒事项 App
    public var name: String
    public let source: ListSource
    public var colorHex: String
    public var available: Bool // 是否真的存在于系统中
    public var prompt: String? // 用户对列表的描述
    public var neglected: Bool // 用户手动选择忽略
    public var iconName: String
    
    public init(id: String, name: String, colorHex: String, available: Bool, source: ListSource, prompt: String? = nil, neglected: Bool = true, iconName: String = "checkmark") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.available = available
        self.source = source
        self.prompt = prompt
        self.neglected = neglected
        self.iconName = iconName
    }
}

// MARK: - Transferable (Drag & Drop)

extension ListInfo: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .data) { listInfo in
            try JSONEncoder().encode(listInfo)
        } importing: { data in
            try JSONDecoder().decode(ListInfo.self, from: data)
        }
    }
}

// MARK: - 名称 → SF Symbol 图标映射

extension ListInfo {
    /// 根据列表名称自动匹配 SF Symbol 图标名
    /// 优先级：用户自定义映射 > 系统静态映射 > source 兜底
    static func iconName(for listName: String, source: ListSource) -> String {
        let lowercased = listName.lowercased()

        // ① 优先查用户自定义映射（keyword → iconName）
        let userMapping = ListStore.loadUserIconMapping()
        for (keyword, icon) in userMapping {
            if lowercased.contains(keyword) {
                return icon
            }
        }

        // ② 查系统静态映射
        for (keyword, icon) in Self.iconMapping {
            if lowercased.contains(keyword) {
                return icon
            }
        }

        // ③ 兜底
        return source == .calendar ? "calendar" : "checkmark"
    }

    private static let iconMapping: [String: String] = {
        let groups: [(keywords: [String], icon: String)] = [
            (["工作", "work"], "briefcase.fill"),
            (["个人", "personal"], "person.fill"),
            (["家庭", "family", "生活", "daily", "日常"], "house.fill"),
            (["学习", "study", "学校", "school"], "book.fill"),
            (["健康", "health"], "heart.fill"),
            (["健身", "运动"], "figure.run"),
            (["旅行", "travel"], "airplane"),
            (["生日", "birthday"], "gift.fill"),
            (["购物", "shopping"], "cart.fill"),
            (["财务", "finance"], "dollarsign.circle.fill"),
            (["阅读", "read"], "book.pages.fill"),
            (["项目", "project"], "square.grid.2x2.fill"),
        ]
        var mapping = [String: String]()
        for (keywords, icon) in groups {
            for keyword in keywords {
                mapping[keyword] = icon
            }
        }
        return mapping
    }()
}


/// AI generated event model (parsed from JSON, will be converted to EventItem)
public struct TempEventItem: Codable, Sendable {
    // 基础信息
    public let title: String
    public let type: EventType

    // 时间相关
    public let startTime: String?
    public let endTime: String?
    public let reminderTime: String?
    public let alarmTime: String?
    public let frequency: String? // 如 "daily", "weekly" 等

    // 元数据
    public let url: String?
    public let meetingLink: String?
    public let location: String?
    public let notes: String?

    // 标签与类别
    public let tags: [String]?
    public let list: String?

    enum CodingKeys: String, CodingKey {
        case title, type
        case startTime, endTime, reminderTime, alarmTime, frequency
        case url, meetingLink, location, notes
        case tags, list
    }

    public nonisolated init(
        title: String,
        type: EventType,
        startTime: String? = nil,
        endTime: String? = nil,
        reminderTime: String? = nil,
        alarmTime: String? = nil,
        frequency: String? = nil,
        url: String? = nil,
        meetingLink: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        tags: [String]? = nil,
        list: String? = nil
    ) {
        self.title = title
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.reminderTime = reminderTime
        self.alarmTime = alarmTime
        self.frequency = frequency
        self.url = url
        self.meetingLink = meetingLink
        self.location = location
        self.notes = notes
        self.tags = tags
        self.list = list
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.type = try container.decode(EventType.self, forKey: .type)
        self.startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        self.endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        self.reminderTime = try container.decodeIfPresent(String.self, forKey: .reminderTime)
        self.alarmTime = try container.decodeIfPresent(String.self, forKey: .alarmTime)
        self.frequency = try container.decodeIfPresent(String.self, forKey: .frequency)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.meetingLink = try container.decodeIfPresent(String.self, forKey: .meetingLink)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
        self.list = try container.decodeIfPresent(String.self, forKey: .list)
    }
}

/// AI generated event model (processed from TempEventItem, waiting to be saved)
public struct EventItem: Codable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let type: EventType
    
    // 时间对象 (已从 String 转换)
    public let startTime: Date?
    public let endTime: Date?
    public let reminderTime: Date?
    public let alarmTime: Date?
    public let frequency: String?
    
    // 元数据
    public let url: String?
    public let meetingLink: String?
    public let location: String?
    public let notes: String?
    public let tags: [String]?
    
    // 列表匹配信息
    public let listNameFromAI: String? // AI 原始建议的列表名
    public var listInfo: ListInfo? = nil
    
    public var status: EventStatus = .pending
    public var isSelected: Bool = true
}

/// System calendar / reminder event model
public struct EventEntry: Identifiable, Sendable {
    public let id: String            // 系统 identifier
    public let title: String
    public let type: EventType
    public let isAllDayReminder: Bool // 仅对 reminder 有意义：true = 全天提醒事项（指定日期无时间）
    public let startTime: Date?
    public let endTime: Date?
    public let dueDate: Date?
    public let completionDate: Date?
    public let isCompleted: Bool
    public let recurrenceRule: String?
    public let listName: String
    public let listID: String         // 系统日历/列表标识符，用于精确过滤
    public let listColorHex: String
    public let notes: String?
    public let location: String?
    public let url: String?

    public init(
        id: String,
        title: String,
        type: EventType,
        isAllDayReminder: Bool = false,
        startTime: Date? = nil,
        endTime: Date? = nil,
        dueDate: Date? = nil,
        completionDate: Date? = nil,
        isCompleted: Bool = false,
        recurrenceRule: String? = nil,
        listName: String,
        listID: String = "",
        listColorHex: String = "#000000",
        notes: String? = nil,
        location: String? = nil,
        url: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.isAllDayReminder = isAllDayReminder
        self.startTime = startTime
        self.endTime = endTime
        self.dueDate = dueDate
        self.completionDate = completionDate
        self.isCompleted = isCompleted
        self.recurrenceRule = recurrenceRule
        self.listName = listName
        self.listID = listID
        self.listColorHex = listColorHex
        self.notes = notes
        self.location = location
        self.url = url
    }
}

// MARK: - Extensions
extension TempEventItem {
    /// 阶段 1：纯数据转换 (String -> Date)
    /// 这个方法只负责解析时间，不负责查找系统日历，保持同步和高效
    public nonisolated func toInitialEventItem() -> EventItem {
        // 提醒事项没有 start_time/end_time，保持 nil；日程事件兜底当前时间
        let start: Date?
        if self.type == .reminder {
            start = Date.parse(self.startTime)   // reminder 无 startTime → nil
        } else {
            start = Date.parse(self.startTime) ?? Date()
        }

        let end: Date?
        if let e = Date.parse(self.endTime) {
            end = e
        } else if let s = start {
            end = (self.type == .allDay)
                ? Calendar.current.date(byAdding: .day, value: 1, to: s) ?? s
                : s.addingTimeInterval(3600)
        } else {
            end = nil
        }
        
        return EventItem(
            id: UUID(),
            title: self.title,
            type: self.type,
            startTime: start,
            endTime: end,
            reminderTime: Date.parse(self.reminderTime),
            alarmTime: Date.parse(self.alarmTime),
            frequency: self.frequency,
            url: self.url,
            meetingLink: self.meetingLink,
            location: self.location,
            notes: self.notes,
            tags: self.tags,
            listNameFromAI: self.list // 保留 AI 的原始建议，供后续查找
        )
    }
}
