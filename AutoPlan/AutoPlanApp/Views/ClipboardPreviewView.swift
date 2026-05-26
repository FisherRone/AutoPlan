//
//  ClipboardPreviewView.swift
//  AutoPlan
//
//  autoplan:// URL scheme 处理流程：
//  读取剪贴板 → 自动判断文本/图片 → AutoPlanEngine 处理 → 预览确认 → 保存
//

import SwiftUI
import AutoPlanCore
import AppKit
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AutoPlan", category: "URLScheme")

struct ClipboardPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var events: [EventItem] = []
    @State private var phase: Phase = .loading

    enum Phase {
        case loading
        case error(String)
        case preview
        case saving
        case saved([EventItem])
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                loadingView
            case .error(let msg):
                errorView(msg)
            case .preview:
                previewView
            case .saving:
                savingView
            case .saved(let items):
                savedView(items)
            }
        }
        .frame(minWidth: 400, maxWidth: 520, minHeight: 200, maxHeight: 600)
        .task { await processClipboard() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在处理剪贴板内容…")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Error

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            ErrorSnippetView(message: msg)
            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Preview

    private var previewView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("确认日程")
                    .font(.headline)
                Spacer()
                Text("共 \(events.count) 项")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(events.indices, id: \.self) { index in
                        SnippetEventRow(event: events[index], isEditable: true) {
                            events[index].isSelected.toggle()
                        }
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("确认保存") { saveEvents() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(events.allSatisfy { !$0.isSelected })
            }
            .padding()
        }
    }

    // MARK: - Saving

    private var savingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在保存…")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Saved

    private func savedView(_ items: [EventItem]) -> some View {
        VStack(spacing: 12) {
            EventSavedSnippetView(events: items)
            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Logic

    /// 读取剪贴板，自动判断文本/图片，调用 AutoPlanEngine 处理
    private func processClipboard() async {
        logger.info("📋 开始读取剪贴板…")
        let pasteboard = NSPasteboard.general

        // 文本
        var textContent = ""
        if let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            textContent = text
            logger.info("📋 检测到剪贴板文本, 长度: \(textContent.count) 字符")
        }

        // 图片
        var cgImages: [CGImage] = []
        if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage] {
            for nsImage in images {
                if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    cgImages.append(cgImage)
                }
            }
            logger.info("📋 检测到剪贴板图片: \(cgImages.count) 张")
        }

        guard !textContent.isEmpty || !cgImages.isEmpty else {
            logger.warning("⚠️ 剪贴板中无文本或图片内容")
            phase = .error("剪贴板中没有文本或图片内容。\n请先复制内容再使用此功能。")
            return
        }

        logger.info("🚀 调用 AutoPlanEngine.process, textLen=\(textContent.count), images=\(cgImages.count)")
        do {
            let result = try await AutoPlanEngine.process(
                textContent,
                cgImages: cgImages.isEmpty ? nil : cgImages
            )
            guard !result.isEmpty else {
                logger.warning("⚠️ process 返回空结果")
                phase = .error("未识别到任何日程或提醒事项。")
                return
            }
            events = result
            logger.info("✅ process 完成, 识别到 \(events.count) 项日程")
            phase = .preview
        } catch AutoPlanError.noItemsRecognized {
            logger.warning("⚠️ noItemsRecognized")
            phase = .error("未识别到任何日程或提醒事项。")
        } catch {
            logger.error("❌ process 失败: \(error.localizedDescription)")
            phase = .error("处理失败: \(error.localizedDescription)")
        }
    }

    /// 保存用户选中的日程
    private func saveEvents() {
        let selected = events.filter { $0.isSelected }
        guard !selected.isEmpty else { return }

        logger.info("💾 开始保存 \(selected.count) / \(events.count) 项日程")
        phase = .saving
        Task {
            do {
                let (summary, saved) = try await AutoPlanEngine.saveItems(selected)
                logger.info("✅ 保存完成: \(summary)")
                phase = .saved(saved)
            } catch {
                logger.error("❌ 保存失败: \(error.localizedDescription)")
                phase = .error("保存失败: \(error.localizedDescription)")
            }
        }
    }
}
