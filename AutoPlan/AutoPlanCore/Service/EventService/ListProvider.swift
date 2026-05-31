//
//  ListProvider.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/10.
//


// Sources/AutoPlanCore/Service/EventService/ListMatcher.swift

import Foundation
import SwiftyBeaver

public struct ListMatchResult {
    public let matchedInfo: ListInfo?
    public let status: ListMatchStatus
}


public enum ListMatchStatus: Codable, Sendable {
    case exactMatch      // 完美匹配
    case multipleMatches // 找到多个，已选其一（警告）
    case defaulted       // 未找到，使用系统默认（提示）
    case none            // 无需匹配（如事项本身没有 list 建议）
}

public struct ListMatcher {
    /// 根据 AI 建议查找最匹配的系统列表
    public static func match(name: String?, type: EventType, settings: CoreConfiguration) -> ListMatchResult {
        guard let name = name, !name.isEmpty else {
            return ListMatchResult(matchedInfo: nil, status: ListMatchStatus.none)
        }

        // 1. 确定搜索池 (日历 vs 提醒事项)
        let pool: [ListInfo] = (type == .reminder) ? settings.userReminderLists : settings.userCalendarLists
        
        // 2. 过滤可用且未被忽略的同名项 (不区分大小写)
        let matches = pool.filter { 
            $0.available && !$0.neglected && $0.name.lowercased() == name.lowercased() 
        }

        if matches.isEmpty {
            logger.info("未找到匹配列表: \(name), 将使用系统默认", context: "ListMatcher")
            return ListMatchResult(matchedInfo: nil, status: ListMatchStatus.defaulted)
        }

        if matches.count > 1 {
            let warning = String(localized: "找到多个名为 '\(name)' 的列表，已选择第一个。")
            logger.warning("\(warning)", context: "ListMatcher")
            return ListMatchResult(matchedInfo: matches.first, status: ListMatchStatus.multipleMatches)
        }

        return ListMatchResult(matchedInfo: matches.first, status: ListMatchStatus.exactMatch)
    }
}
