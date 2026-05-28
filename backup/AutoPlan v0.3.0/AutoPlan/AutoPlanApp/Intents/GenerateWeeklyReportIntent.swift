
//
//  GenerateWeeklyReportIntent.swift
//  AutoPlan
//
//  快捷指令：生成周报
//  接受日期参数，生成该周的 Markdown 周报文件

import AppIntents
import AutoPlanCore
import OSLog
import SwiftUI
import UniformTypeIdentifiers

nonisolated private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AutoPlan", category: "Shortcuts")


struct GenerateWeeklyReportIntent: AppIntent {
    static let title: LocalizedStringResource = "生成周报"
    static let description: IntentDescription = "根据指定日期生成该周的 Markdown 周报文件"

    static let openAppWhenRun: Bool = false

    @Parameter(title: "日期", description: "周报所属的日期（自动计算该日期所在的周）")
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("生成 \(\.$date) 所在周的周报")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        logger.info("🚀 GenerateWeeklyReportIntent 开始执行")

        let targetDate = date ?? Date()
        logger.info("📅 目标日期: \(targetDate)")

        do {
            let config = try await ListStore.refresh()
            let markdownContent: String = try await ReportWriter.writeWeeklyReport(
                date: targetDate,
                config: config
            )

            logger.info("✅ 周报生成成功，长度: \(markdownContent.count) 字符")

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let dateStr = formatter.string(from: targetDate)
            let filename = "weekly_report_\(dateStr).md"

            // 使用沙盒内路径，与 ReportWriter.reportDirectory() 保持一致
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dirURL = appSupport.appendingPathComponent("AutoPlan/Reports")
            let fileURL = dirURL.appendingPathComponent(filename)

            var intentFile = IntentFile(
                fileURL: fileURL,
                filename: filename,
                type: UTType("net.daringfireball.markdown")
            )
            intentFile.removedOnCompletion = false

            return .result(value: intentFile)

        } catch {
            logger.error("❌ 周报生成失败: \(error.localizedDescription)")
            throw error
        }
    }
}
