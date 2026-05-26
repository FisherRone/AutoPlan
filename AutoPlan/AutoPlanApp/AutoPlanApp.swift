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
        // 获取主屏幕的 backingScaleFactor (比例系数)
        if let mainScreen = NSScreen.main {
            let screenScale = mainScreen.backingScaleFactor
            print("Current screen scale factor: \(screenScale)")
            let defaultBodySize: CGFloat = 13.0
            let currentBodySize = NSFont.preferredFont(forTextStyle: .body).pointSize
            let fontScale = currentBodySize / defaultBodySize
            print("当前文字放大系数: \(fontScale)")
        }
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

