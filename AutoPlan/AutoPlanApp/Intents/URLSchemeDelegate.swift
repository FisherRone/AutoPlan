//
//  URLSchemeDelegate.swift
//  AutoPlan
//
//  在 NSApplicationDelegate 层面拦截 URL scheme 调用，
//  避免 SwiftUI Scene 自动弹出主窗口。
//  - autoplan-weekly-report:// → 后台生成周报，发通知，隐藏 app
//  - autoplan:// → 由 SwiftUI Window scene 处理
//

import AppKit
import AutoPlanCore
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AutoPlan", category: "URLScheme")

final class URLSchemeDelegate: NSObject, NSApplicationDelegate {

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let scheme = url.scheme?.lowercased() else { continue }
            logger.info("🔗 [Delegate] 收到 URL: \(url.absoluteString)")

            switch scheme {
            case "autoplan-weekly-report":
                logger.info("🔗 匹配 autoplan-weekly-report, 后台生成周报")
                Task {
                    await handleWeeklyReport()
                }

            case "autoplan":
                // 由 SwiftUI Window scene 负责弹出预览窗口
                logger.debug("🔗 autoplan:// 路由到 Window scene")

            default:
                logger.warning("🔗 未识别的 scheme: \(scheme)")
            }
        }
    }

    // MARK: - Private

    private func handleWeeklyReport() async {
        await NotificationManager.shared.requestAuthorizationIfNeeded()

        do {
            let config = try await ListStore.refresh()
            try await ReportWriter.writeWeeklyReport(date: Date(), config: config)

            let folderPath = NotificationManager.shared.defaultReportFolderPath
            await NotificationManager.shared.sendWeeklyReportNotification(folderPath: folderPath)

            logger.info("✅ 周报处理完毕，隐藏 app")
        } catch {
            logger.error("❌ 周报生成失败: \(error.localizedDescription)")
        }

        // 没有窗口需要展示，隐藏整个 app
        await MainActor.run {
            NSApp.hide(nil)
        }
    }
}
