//
//  NotificationManager.swift
//  AutoPlan
//
//  系统通知管理：授权、分类注册、发送、action 回调
//

import UserNotifications
import AppKit
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AutoPlan", category: "Notification")

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private let openFolderActionID = "OPEN_REPORT_FOLDER"
    private let reportCategoryID = "WEEKLY_REPORT"

    private override init() {
        super.init()
    }

    /// App 启动时调用，设置 delegate 并注册通知分类
    func setup() {
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
        logger.info("✅ NotificationManager setup 完成，delegate 已设置，categories 已注册")
    }

    /// 请求通知权限（仅在未决定时弹出授权弹窗）
    func requestAuthorizationIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status = settings.authorizationStatus
        logger.debug("🔔 当前通知权限状态: \(status.rawValue)")
        guard status == .notDetermined else { return }
        logger.info("🔔 首次请求通知权限")
        let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        logger.info("🔔 通知权限请求结果: \(granted == true ? "已授权" : "已拒绝")")
    }

    // MARK: - Categories

    private func registerCategories() {
        let openAction = UNNotificationAction(
            identifier: openFolderActionID,
            title: "打开文件夹",
            options: .foreground
        )
        let category = UNNotificationCategory(
            identifier: reportCategoryID,
            actions: [openAction],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Send

    /// 发送"周报已生成"通知，带打开文件夹按钮
    func sendWeeklyReportNotification(folderPath: String) async {
        logger.info("📬 准备发送周报通知, folderPath: \(folderPath)")
        let content = UNMutableNotificationContent()
        content.title = "周报已生成"
        content.body = "已保存至 Reports 文件夹"
        content.categoryIdentifier = reportCategoryID
        content.userInfo = ["reportFolder": folderPath]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("✅ 周报通知已发送")
        } catch {
            logger.error("❌ 发送通知失败: \(error.localizedDescription)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        logger.info("👆 收到通知 action: \(response.actionIdentifier)")

        guard response.actionIdentifier == openFolderActionID else { return }

        let folderPath = response.notification.request.content.userInfo["reportFolder"] as? String
            ?? defaultReportFolderPath
        logger.info("📂 打开文件夹: \(folderPath)")
        NSWorkspace.shared.open(URL(fileURLWithPath: folderPath))
    }
}

// MARK: - Helpers

extension NotificationManager {
    var defaultReportFolderPath: String {
        let appSupport = NSSearchPathForDirectoriesInDomains(
            .applicationSupportDirectory, .userDomainMask, true
        ).first ?? "/tmp"
        return (appSupport as NSString).appendingPathComponent("AutoPlan/Reports")
    }
}
