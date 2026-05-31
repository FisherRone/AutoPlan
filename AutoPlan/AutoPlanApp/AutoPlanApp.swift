//
//  AutoPlanApp.swift
//  AutoPlanApp
//
//  Created by 荣子鱼 on 2026/5/9.
//

import SwiftUI
import SwiftyBeaver



// MARK: - Main
@main
struct AutoPlanAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // 1. 确保 Prompt 文件存在（放在最前面，不会触发日志更好）
        PromptBuilder.ensureCustomPromptFileExists()
        
        // 2. 配置 SwiftyBeaver 输出目标
        setupLogging()
    }

    var body: some Scene {
        // AutoPlan 使用 AppKit 管理所有 UI
        WindowGroup {
            EmptyView()
        }
        .defaultLaunchBehavior(.suppressed)
    }

    private func setupLogging() {
        // -- 控制台输出（Xcode 里看彩色日志）--
        let console = ConsoleDestination()
        console.minLevel = .verbose          // 开发阶段显示所有日志
        console.format = "$DHH:mm:ss.SSS$d $L $M"  // 时间 + 级别 + 消息
        // 如果想用 Apple 新的 OSLog 带颜色和子系统分类，可以用：
        // console.logPrintWay = .logger(subsystem: "com.yourcompany.AutoPlan", category: "UI")
        // 这里先用传统 print，简单可靠
        console.logPrintWay = .print
        logger.addDestination(console)

        // -- 文件输出（写到 ~/Library/Logs/AutoPlan/app.log）--
        let file = FileDestination()
        file.minLevel = .info
        file.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $L $M $X"
        // 指定日志文件路径
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/AutoPlan")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        let logFileURL = logsDir.appendingPathComponent("app.log")
        file.logFileURL = logFileURL
        logger.addDestination(file)

        // SwiftyBeaver 自带的文件轮转功能，解决日志无限增长
        file.logFileAmount = 1
        file.logFileMaxSize = (10 * 1024 * 1024)  // 10 MB
    }
}

