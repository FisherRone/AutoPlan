//
//  HelloWorldIntent.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/19.
//


import AppIntents
import SwiftUI


struct AutoPlanHelloWorldIntent: AppIntent {
    // 在快捷指令 App 中显示的标题
    static let title: LocalizedStringResource = "helloworld"
    
    // 在快捷指令 App 中显示的描述（可选但推荐）
    static let description = IntentDescription("返回一句问候语")
    
    // 执行逻辑：返回 "hello world" 字符串
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        return .result(value: "hello world")
    }
}
