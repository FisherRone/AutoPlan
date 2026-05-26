//
//  WeeklyStatistics.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/21.
//

import Foundation

/// 周报统计数据
public struct WeeklyStatistics: Sendable {
    /// 本周日程数（含全天日程）
    public let eventCount: Int
    /// 本周提醒事项数（已完成 + 未完成，含全天提醒）
    public let reminderCount: Int

    public init(eventCount: Int, reminderCount: Int) {
        self.eventCount = eventCount
        self.reminderCount = reminderCount
    }
}

extension WeeklyStatistics {
    /// 从 EventEntry 列表计算统计
    public static func from(entries: [EventEntry]) -> WeeklyStatistics {
        let eventCount = entries.filter { $0.type == .event || $0.type == .allDay }.count
        let reminderCount = entries.filter { $0.type == .reminder }.count
        return WeeklyStatistics(eventCount: eventCount, reminderCount: reminderCount)
    }

    /// 转为提示词用的文本摘要
    public var summary: String {
        "本周日程数: \(eventCount)，本周提醒事项数: \(reminderCount)"
    }
}
