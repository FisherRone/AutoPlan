import Testing
import Foundation
import AutoPlanCore

struct PromptTemplateTests {

    // MARK: - 基本填充

    /// 所有区块都有值，正常替换
    @Test func allBlocksFilled() {
        let template = """
        {{INSTRUCTION}}

        {{TIME}}

        {{TAGS}}
        """
        let result = PromptBuilder.renderTemplate(template, with: [
            "INSTRUCTION": "你是助手",
            "TIME": "2026-05-23 10:00",
            "TAGS": "[\"工作\", \"生活\"]"
        ])
        #expect(result == """
        你是助手

        2026-05-23 10:00

        [\"工作\", \"生活\"]
        """)
    }

    /// 单个区块替换
    @Test func singleBlockReplacement() {
        let result = PromptBuilder.renderTemplate("Hello {{NAME}}!", with: [
            "NAME": "World"
        ])
        #expect(result == "Hello World!")
    }

    /// 多个相同占位符全部替换
    @Test func duplicatePlaceholders() {
        let result = PromptBuilder.renderTemplate("{{A}} and {{A}}", with: [
            "A": "value"
        ])
        #expect(result == "value and value")
    }

    // MARK: - 空值处理

    /// 值为 nil → 占位符被移除（替换为空字符串）
    @Test func nilValueRemovesPlaceholder() {
        let result = PromptBuilder.renderTemplate("Start {{MISSING}} End", with: [
            "MISSING": nil
        ])
        #expect(result == "Start  End")
    }

    /// 值为空字符串 → 占位符被移除
    @Test func emptyStringRemovesPlaceholder() {
        let result = PromptBuilder.renderTemplate("Start {{EMPTY}} End", with: [
            "EMPTY": ""
        ])
        #expect(result == "Start  End")
    }

    /// 部分区块为空，部分有值
    @Test func mixedNilAndValue() {
        let template = "{{A}}\n\n{{B}}\n\n{{C}}"
        let result = PromptBuilder.renderTemplate(template, with: [
            "A": "keep A",
            "B": nil,
            "C": "keep C"
        ])
        #expect(result == "keep A\n\n\n\nkeep C")
    }

    // MARK: - 未匹配占位符清理

    /// 模板中有 blocks 字典不存在的占位符 → 被正则清除
    @Test func unmatchedPlaceholderRemoved() {
        let result = PromptBuilder.renderTemplate("{{KNOWN}} and {{UNKNOWN}}", with: [
            "KNOWN": "found"
        ])
        #expect(result == "found and ")
    }

    /// 多个未匹配占位符全部清除
    @Test func multipleUnmatchedRemoved() {
        let result = PromptBuilder.renderTemplate("{{X}}{{Y}}{{Z}}", with: [:])
        #expect(result == "")
    }

    /// 未匹配占位符在文本中间
    @Test func unmatchedInMiddleOfText() {
        let result = PromptBuilder.renderTemplate("before {{ORPHAN}} after", with: [:])
        #expect(result == "before  after")
    }

    // MARK: - 边界情况

    /// 空模板 + 空 blocks → 空字符串
    @Test func emptyTemplateEmptyBlocks() {
        let result = PromptBuilder.renderTemplate("", with: [:])
        #expect(result.isEmpty)
    }

    /// 空模板 + 有 blocks → 空字符串
    @Test func emptyTemplateWithBlocks() {
        let result = PromptBuilder.renderTemplate("", with: ["KEY": "value"])
        #expect(result.isEmpty)
    }

    /// 无占位符的纯文本模板 → 原样返回
    @Test func plainTextNoPlaceholders() {
        let text = "This is just plain text."
        let result = PromptBuilder.renderTemplate(text, with: ["ANY": "thing"])
        #expect(result == text)
    }

    // MARK: - 实际 BasePrompt 模板结构验证

    /// 模拟真实模板：所有区块为空时，结果不含任何 {{...}}
    @Test func realTemplateAllEmpty() {
        let template = """
        {{BASE_INSTRUCTION}}
        {{USER_IDENTITY}}

        # Rules

        {{SYSTEM_TIME}}
        {{LISTS}}
        {{TAGS}}
        {{DATE_WEEKDAY}}
        """
        let result = PromptBuilder.renderTemplate(template, with: [
            "BASE_INSTRUCTION": nil,
            "USER_IDENTITY": nil,
            "SYSTEM_TIME": nil,
            "LISTS": nil,
            "TAGS": nil,
            "DATE_WEEKDAY": nil
        ])
        // 不应残留任何 {{...}}
        #expect(!result.contains("{{"))
        #expect(!result.contains("}}"))
    }

    /// 模拟真实模板：只有 BASE_INSTRUCTION 有值
    @Test func realTemplateOnlyInstruction() {
        let template = """
        {{BASE_INSTRUCTION}}
        {{USER_IDENTITY}}

        # Rules

        {{SYSTEM_TIME}}
        {{LISTS}}
        {{TAGS}}
        {{DATE_WEEKDAY}}
        """
        let result = PromptBuilder.renderTemplate(template, with: [
            "BASE_INSTRUCTION": "你是一个智能助理。",
            "USER_IDENTITY": nil,
            "SYSTEM_TIME": nil,
            "LISTS": nil,
            "TAGS": nil,
            "DATE_WEEKDAY": nil
        ])
        #expect(result.hasPrefix("你是一个智能助理。"))
        #expect(!result.contains("{{"))
    }
}
