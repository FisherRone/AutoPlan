//
//  AutoPlanApp.swift
//  AutoPlanApp
//
//  Created by 荣子鱼 on 2026/5/9.
//

import SwiftUI
import AutoPlanCore

@main
struct AutoPlanAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
        // AutoPlan 使用 AppKit 管理所有 UI
        WindowGroup {
            EmptyView()
        }
        .defaultLaunchBehavior(.suppressed)
    }
}
