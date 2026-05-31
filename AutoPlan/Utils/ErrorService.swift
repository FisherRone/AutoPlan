//
//  ErrorService.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/31.
//

import SwiftUI
import SwiftyBeaver

// 全局 logger 实例，方便整个 App 使用
// App 初始化时已配置 Destination
nonisolated let logger = SwiftyBeaver.self


/*
 如何使用 logger？
 import SwiftyBeaver
 logger.info("任务开始")
 logger.error("坏了")
 logger.warning("不好了")

 someWarningMessage.log() // WarningMessage 直接用这个
 */


/// 纯文本的警告数据结构，不携带任何 UI 样式信息
struct WarningMessage {
    let id: String
    let userText: String
    let logText: String
    let severity: Severity
    
    enum Severity: String {
        case error
        case warning
    }
    
    init(id: String, severity: Severity, userText: String = "", logText: String = "") {
        self.id = id
        self.severity = severity
        self.userText = userText
        self.logText = logText
    }
}


extension WarningMessage {
    /// 根据 severity 自动选择 SwiftyBeaver 对应级别并记录日志
    func log() {
        switch severity {
        case .error:
            logger.error(logText)
        case .warning:
            logger.warning(logText)
        }
    }
}

// MARK: - UI Warning Message
extension WarningMessage {
    /// UI 界面内的小字提醒
    /// ⚠️ 禁止  Coding Agent 在未被要求的情况下自行使用
    func uiNote() -> Text {
        switch severity {
        case .error:
            return Text(userText).font(.caption).foregroundStyle(.red)
        case .warning:
            return Text(userText).font(.caption).foregroundStyle(.orange)
        }
    }
}


// MARK: - Example
// 具体警告实例的定义（任意代码文件开头，集中管理）
/*
enum ExampleWarning {
    case Example1
    case Example2
    
    var message: WarningMessage {
        switch self {
        case .Example1:
            return WarningMessage(
                id: "example.1",
                severity: .error,
                userText: String(localized: "AAAA"), // 这样写才能让 xcode 自动加到翻译文件中。
                logText: "example one."
            )
        case .Example2:
            return WarningMessage(id: "example.2", severity: .error, logText: "example two.")
        }
    }
}
*/
