//
//  CoreConfiguration.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/10.
//


// Sources/AutoPlanCore/Model/CoreConfiguration.swift

public struct CoreConfiguration: Sendable {
    public let useList: Bool
    public let useTags: Bool
    public let userCalendarLists: [ListInfo]
    public let userReminderLists: [ListInfo]
    
    // 构造函数
    public init(useList: Bool, useTags: Bool, userCalendarLists: [ListInfo], userReminderLists: [ListInfo]) {
        self.useList = useList
        self.useTags = useTags
        self.userCalendarLists = userCalendarLists
        self.userReminderLists = userReminderLists
    }
}