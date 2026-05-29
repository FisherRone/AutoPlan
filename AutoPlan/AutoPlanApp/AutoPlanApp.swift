//
//  AutoPlanApp.swift
//  AutoPlanApp
//
//  Created by 荣子鱼 on 2026/5/9.
//

import SwiftUI

@main
struct AutoPlanAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        PromptBuilder.ensureCustomPromptFileExists()
    }

    var body: some Scene {
        // AutoPlan 使用 AppKit 管理所有 UI
        WindowGroup {
            EmptyView()
        }
        .defaultLaunchBehavior(.suppressed)
    }
}
