//
//  Logger.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/1/5.
//

import OSLog

import Foundation

enum LogCategory: String {
    case network = "Network"       // 网络请求与连接
    case ocr     = "OCR"           // 文字识别相关
    case llm     = "LLM"           // 大模型交互相关
    case event   = "EventKit"      // 日历与提醒事项
    case data    = "DataStorage"   // 本地数据库或文件存储
    case ui      = "UserInterface" // 界面交互与动画
    
    /// 可以用来返回更详细的中文字符串描述
    var description: String {
        switch self {
        case .network: return "网络连接与数据传输"
        case .ocr:     return "文本识别处理"
        case .llm:     return "大语言模型交互"
        case .event:   return "系统日历与提醒事项"
        case .data:    return "本地数据持久化"
        case .ui:      return "用户界面刷新"
        }
    }
}

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "AutoPlan"
}
