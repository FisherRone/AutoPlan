//
//  TemplatePreviewView.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/26.
//
import SwiftUI
import AppKit
import AutoPlanCore

struct TemplatePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    var purpose: ModelPurpose = .extraction

    private var templateContent: String {
        switch purpose {
        case .extraction:
            return PromptBuilder.templatePrompt
        case .weeklyReport:
            return PromptBuilder.templateWeeklyReportPrompt
        }
    }

    private var title: String {
        switch purpose {
        case .extraction:
            return "日程提取提示词模板"
        case .weeklyReport:
            return "周报撰写提示词模板"
        }
    }

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
                Text(templateContent)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        }
    }
}
