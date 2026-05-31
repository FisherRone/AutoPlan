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
- 写 UI 组件时，或 debug 时，必须用 xcode mcp 查文档！！！
- 对于你不太了解的东西，必须用 xcode mcp 查文档！！！

⛔️ 禁止直接编辑 AutoPlan/AutoPlan.xcodeproj

- LSP 报的 Internal SourceKit error 是 Swift Package Manager 在 Xcode 外部分析的已知问题，不是代码语法错误。看到它就直接忽略。

### 测试 & DEBUG
- xcode mcp 可编译，查看报错 和 issue
- 使用 log：
```swift
// 任意代码文件中：
import SwiftyBeaver
logger.info("任务开始")
logger.debug("缓存命中", context: "CacheManager")
anyWarningMessage.log() // WarningMessage 对象直接 log
```

### 错误处理设计

#### 错误类型定义
- **Error + LocalizedError**：异常流程，`throw`/`catch` 传播，中断执行。用于网络失败、解码错误等底层/后台代码。
- **WarningMessage**：用于"保存失败"等上层代码。
  - 提供了.log() 方法 和 .uiNote()，详见 ErrorService.swift
  - 设计目的是用于方便地 log 和 UI 展示。
- **怎么选**：
  - 后台报错：需要传播/直接中断 ➡️ 用 Error
  - 前台用户的操作有问题/失败：只需要 log、 UI 展示，➡️ 用 WarningMessage

#### 代码内统一管理
- 错误定义在所属代码文件的前面统一管理。参考 ErrorService.swift，OCR.swift


### 清理
- 遇到不明不白的 bug，可能可以通过清理来解决。
- **禁止自行清理**，需要时提醒用户手动清理。
1. Xcode: cmd + shift + K
2. Xcode: File -> Packages -> Reset Package Caches
3. 
```bash
rm -rf ~/Library/Preferences/io.github.FisherRone.AutoPlanApp.plist
rm -rf ~/Library/Application Support/AutoPlan
rm -rf ~/Library/Developer/Xcode/DerivedData/AutoPlan*
```
4. 钥匙串.app 删除钥匙串

## 【重要】工具使用
1. 修改代码（增删改）必须用系统（qoder）给你的工具。
2. 搜索代码、读代码必须用 xcode mcp 的工具，目前系统的 grep_code  有严重 bug。

### 【重要】Xcode MCP 工具使用
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

