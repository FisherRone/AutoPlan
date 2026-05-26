//
//  AutoPlanAppApp.swift
//  AutoPlanApp
//
//  Created by 荣子鱼 on 2026/5/9.
//

import SwiftUI
import AppIntents
import AutoPlanCore

@main
struct AutoPlanAppApp: App {
    init() {
        PromptBuilder.ensureCustomPromptFileExists()
    }

    var body: some Scene {
        WindowGroup {
            
            TabView {
                Tab("通用", systemImage: "gearshape") {
                    ModelConfigView()
                }

                Tab("日程提取", systemImage: "list.bullet") {
                    ExtractorView()
                }

                Tab("周报", systemImage: "doc.text") {
                    WeeklyReportView()
                }

                Tab("关于", systemImage: "info.circle") {
                    AboutHelpView()
                }
            }
            .frame(minWidth: 540, idealWidth: 540, minHeight: 500, idealHeight: 600)
        }
    }
}




struct MyAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AutoPlanHelloWorldIntent(),
            phrases: [
                "\(.applicationName) say hello",
                "Say hello in \(.applicationName)",
                "Hello from \(.applicationName)"
            ],
            shortTitle: "Say Hello",
            systemImageName: "hand.wave"
        )
    }
}
