//
//  PromptTutorialView.swift
//  AutoPlanApp
//
//  Created by Assistant on 2026/5/24.
//

import SwiftUI

struct PromptTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            mainPromptVariables
            Divider().padding(.vertical, 8)
        }
        .padding(24)
    }

    // MARK: - Main Prompt Variables

    private var mainPromptVariables: some View {
        VStack(alignment: .leading, spacing: 16) {
            VariableRow(
                variable: "BASE_INSTRUCTION",
                description: String(localized: "基础指令内容"),
                detail: String(localized: "从 BaseInstruction.txt 或用户自定义提示词文件读取。定义 LLM 的核心角色和任务说明。\n\n**实际填充内容示例**：\n```\n你是一个智能日程助理。\n输入的内容是用户收到的一条信息，该用户想要记录该信息中的日程或提醒事项。\n你的任务：分析用户的输入和意图，提取日程或提醒事项。并输出为符合以下定义的 JSON 列表 (Array) 格式。\n\n# 输出字段定义 (JSON列表中每个对象的结构)\n## 必填项\n- title: String.\n- type: String. \"event\" | \"all-day\" | \"reminder\"\n## 可选项\n- start_time: String?\n    - YYYY-MM-DD HH:MM (only for event)\n    - YYYY-MM-DD (only for all-day)\n- end_time: String?\n    - YYYY-MM-DD HH:MM (only for event)\n    - YYYY-MM-DD (only for all-day)\n- reminder_time: String?（only for reminder）YYYY-MM-DD HH:MM 或 YYYY-MM-DD\n- url: String? (meeting links, meeting IDs, or web URLs)\n- location: String?\n- list: String? 对象所属的列表，必须从之后给定的选项中选择。\n...\n# Output Format\n1. Strict JSON only. No explanatory text.\n2. Must wrap in a JSON array [ ].\n3. 直接返回 JSON 数组，不做任何解释或说明。\n```")
            )

            VariableRow(
                variable: "USER_INSTRUCTION",
                description: String(localized: "用户身份信息"),
                detail: String(localized: "暂未使用（值为空）。预留用于注入用户个性化信息。")
            )

            VariableRow(
                variable: "CURRENT_TIME",
                description: String(localized: "当前请求时间"),
                detail: String(localized: "格式：ISO 8601 (YYYY-MM-DD HH:MM:SS)\n用于推断相对时间和判断时间合理性。\n\n**实际填充内容示例**：\n```\n2026-05-24 16:30:00. Only indicates the times of current request.\n```")
            )

            VariableRow(
                variable: "LISTS",
                description: String(localized: "可用的日历和提醒事项列表"),
                detail: String(localized: "用户授权的所有日历和提醒事项列表。\nLLM 从中选择匹配的列表名称填入 `list` 字段。\n\n**实际填充内容示例**：\n```\nCalendar Lists (for type: \"event\" or \"all-day\"):\n- \"工作\"\n- \"个人\"\n\nReminder Lists (for type: \"reminder\"):\n- \"待办\"\n- \"购物清单\"\n\nSelect a matching list from the choices above for the 'list' field. If none match, leave it blank.\n```")
            )

            VariableRow(
                variable: "TAGS",
                description: String(localized: "可用的标签列表"),
                detail: String(localized: "从日历中提取的所有唯一标签。\nLLM 从中选择合适的标签填入 `tags` 字段。\n\n**实际填充内容示例**：\n```\n[\"工作\", \"生活\", \"重要\", \"会议\"]\nSelect matching items from the list above for the 'tags' field.\nIf none match, leave it blank.\n```")
            )

            VariableRow(
                variable: "DATE_WEEKDAY",
                description: String(localized: "日期与星期几对照表"),
                detail: String(localized: "以当前日期为中心的前后 15 天日期-星期映射表。帮助 LLM 将\"星期几\"、\"下周三\"等相对时间转换为准确日期。\n\n**实际填充内容示例**：\n```\n2026-05-09 星期六\n2026-05-10 星期日\n2026-05-11 星期一\n...\n2026-05-23 星期五\n2026-05-24 星期六(current request)\n2026-05-25 星期日\n...\n2026-06-08 星期一\n```")
            )
        }
    }
}

// MARK: - Variable Row Component

private struct VariableRow: View {
    let variable: String
    let description: String
    let detail: String

    @State private var showDetail = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("{{\(variable)}}")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)

                    Button(action: { showDetail.toggle() }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "点击查看详细说明"))
                    .popover(isPresented: $showDetail, arrowEdge: .trailing) {
                        PopoverContent(title: variable, content: detail)
                    }
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .cornerRadius(8)
    }
}

// MARK: - Popover Content

private struct PopoverContent: View {
    let title: String
    let content: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("{{\(title)}}")
                    .font(.headline)
                    .foregroundColor(.accentColor)

                Divider()

                Text(content)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 400)
            .padding()
        }
    }
}

#Preview {
    PromptTutorialView()
}

// MARK: - Prompt Variables Sheet

struct PromptVariablesSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var title = String(localized: "日程提取提示词占位符说明")

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            ScrollView {
                PromptTutorialView()
                    .padding(20)
            }
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 400, idealHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
