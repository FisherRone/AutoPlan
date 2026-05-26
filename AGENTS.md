# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## 5. Project-associated Notes
## 项目概述
- 功能：连接 LLM 服务，识别输入的图片或文本信息，转换成日程或提醒事项并保存。目前提供快捷指令调用方式。
- macOS15.0+
- 本项目不开启沙盒。
- 本项目的发行包使用 ad-hoc 签名。

## 开发规范

### 通用
- 尽量不使用 APPKit 等非跨平台技术。
- 使用原生、优雅、现代、简洁的代码风格。
- 采取最小化修改策略。
- 优先检查并使用已实现的服务和资源，不重复造轮子。
- 必须 100% 相信用户提供的当前状态的描述。并且你的思考方向不能和这些描述冲突。
- 思考大于 3 轮，且无确凿结论时。尝试进行以下操作之一：
  - 查文档。
  - 直接汇报思考结果，并提示用户重启 xcode 并清理缓存，然后重新编译运行。不硬猜。
  - 直接汇报思考结果，并向用户提出关键问题。
  - 因为事情往往没你想得那么复杂。
- 对于你不太了解的东西，必须查文档！！！


- LSP 报的 Internal SourceKit error 是 Swift Package Manager 在 Xcode 外部分析的已知问题，不是代码语法错误。看到它就直接忽略。

### 测试
- AutoPlanCore 内的测试无法通过 mcp 运行，必须由开发者手动用 Xcode 打开 AutoPlanCore 后运行。

### 清理
- 遇到不明不白的 bug，可能可以通过清理来解决。
- **禁止自行清理**，需要时提醒用户手动清理。
1. Xcode: cmd + shift + K
2. Xcode: File -> Packages -> Reset Package Caches
3. rm -rf ~/Library/Preferences/io.github.FisherRone.AutoPlanApp.plist
4. rm -rf ~/Library/Application Support/AutoPlan
5. rm -rf ~/Library/Developer/Xcode/DerivedData/AutoPlan*
6. 钥匙串.app 删除钥匙串


### UI
- 设置深色模式下背景颜色切换，用 Color("ChatBackground")，深色模式下是黑色，否则是白色。

## 【重要】Xcode MCP 工具使用
- XcodeListWindows：列出当前 Xcode 窗口信息，可获取 `tabIdentifier`
  - 首次使用任何 Xcode MCP 工具前，必须先调用 XcodeListWindows 获取 tabIdentifier：
  - 后续工具调用必须传入此 tabIdentifier
- DocumentationSearch：搜索 Apple 官方文档。（涉及 Apple 新特性必做）
- BuildProject：编译项目（会等待完成）
- XcodeListNavigatorIssues：查看 Issue Navigator 中的代码问题
- GetBuildLog：获取编译日志。

### 查看运行时日志
- ExecuteSnippet：可获取 `print` 输出用于调试，适合查看代码中的 print 日志
- GetBuildLog：可辅助捕获部分崩溃信息
- Xcode Debug Area：完整日志需依赖 Xcode 的 Debug Area（需要用户在 Xcode 中查看）

