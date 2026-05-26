//
//  EventEnricher.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/10.
//


// Sources/AutoPlanCore/Service/EventService/EventEnricher.swift

import Foundation

public struct EventEnricher {
    /// 将 AI 的原始解析结果增强为带系统匹配信息的 EventItem
    public static func enrich(
        tempItems: [TempEventItem], 
        settings: CoreConfiguration
    ) -> [EventItem] {
        return tempItems.map { temp in
            // 1. 基本转换 (String -> Date 等)
            let initialItem = temp.toInitialEventItem() 
            
            // 2. 调用 ListMatcher 进行匹配
            // 这里利用 settings 中缓存好的 userCalendarLists 和 userReminderLists
            let matchResult = ListMatcher.match(
                name: temp.list,
                type: temp.type,
                settings: settings
            )
            
            // 3. 组装最终成品
            var finalItem = initialItem
            finalItem.listInfo = matchResult.matchedInfo
            
            return finalItem
        }
    }
}
