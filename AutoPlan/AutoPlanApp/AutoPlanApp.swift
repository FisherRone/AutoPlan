//
//  AutoPlanAppApp.swift
//  AutoPlanApp
//
//  Created by 荣子鱼 on 2026/5/9.
//

import SwiftUI
import AppIntents
import AutoPlanCore
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AutoPlan", category: "URLScheme")

@main
struct AutoPlanAppApp: App {
    @NSApplicationDelegateAdaptor(URLSchemeDelegate.self) var urlSchemeDelegate

    init() {
        PromptBuilder.ensureCustomPromptFileExists()
        NotificationManager.shared.setup()
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
        .handlesExternalEvents(matching: [])  // 主窗口不响应 URL scheme
        
        // autoplan:// → 单独弹出预览窗口，不经过主界面
        Window("日程预览", id: "clipboard-preview") {
            ClipboardPreviewView()
        }
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: "autoplan"))
    }
}
