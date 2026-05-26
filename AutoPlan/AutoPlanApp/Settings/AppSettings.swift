//
//  Source/AutoPlanApp/Settings/AppSettings.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/18.
//

import SwiftUI
import AutoPlanCore
import Combine
import Observation

enum AppConfig {
    static let appName = "AutoPlan"
    static let version = "1.0.0"
}

@Observable
@MainActor
public final class AppSettings {
    public static let shared = AppSettings()
    private init() {
        /*
         UserDefaults.standard.register(defaults: [
         "createEventOnly": true
         ])
         */
    } // 确保单例
    
    // MARK: - 界面
    
    // MARK: - Prompt
    
    var useCustomExtractionPrompt: Bool = UserDefaults.standard.bool(forKey: "useCustomExtractionPrompt") {
        didSet {
            UserDefaults.standard.set(useCustomExtractionPrompt, forKey: "useCustomExtractionPrompt")
        }
    }
    
    var useCustomWeeklyReportPrompt: Bool = UserDefaults.standard.bool(forKey: "useCustomWeeklyReportPrompt") {
        didSet {
            UserDefaults.standard.set(useCustomWeeklyReportPrompt, forKey: "useCustomWeeklyReportPrompt")
        }
    }
    
    var userPrompt: String = UserDefaults.standard.string(forKey: "userPrompt") ?? "" {
        didSet {
            UserDefaults.standard.set(userPrompt, forKey: "userPrompt")
        }
    }
    
    var useTags: Bool = UserDefaults.standard.bool(forKey: "useTags") {
        didSet {
            UserDefaults.standard.set(useTags, forKey: "useTags")
        }
    }
    
    // MARK: - LLM 模型选择

    /// 日程提取模型：当前选中的模型 name
    var selectedModelName: String = UserDefaults.standard.string(forKey: "selectedModelName") ?? "" {
        didSet {
            UserDefaults.standard.set(selectedModelName, forKey: "selectedModelName")
            UserDefaults.standard.synchronize()
        }
    }

    /// 日程提取模型：当前选中模型对应的 providerID
    var selectedProviderID: String = UserDefaults.standard.string(forKey: "selectedProviderID") ?? "" {
        didSet {
            UserDefaults.standard.set(selectedProviderID, forKey: "selectedProviderID")
        }
    }

    /// 周报撰写模型：当前选中的模型 name
    var weeklyReportModelName: String = UserDefaults.standard.string(forKey: "weeklyReportModelName") ?? "" {
        didSet {
            UserDefaults.standard.set(weeklyReportModelName, forKey: "weeklyReportModelName")
            UserDefaults.standard.synchronize()
        }
    }

    /// 周报撰写模型：当前选中模型对应的 providerID
    var weeklyReportProviderID: String = UserDefaults.standard.string(forKey: "weeklyReportProviderID") ?? "" {
        didSet {
            UserDefaults.standard.set(weeklyReportProviderID, forKey: "weeklyReportProviderID")
        }
    }
    
    public var userCalendarLists: [ListInfo] {
            get { getList(forKey: "userCalendarLists") }
            set { setList(newValue, forKey: "userCalendarLists") }
        }

    public var userReminderLists: [ListInfo] {
        get { getList(forKey: "userReminderLists") }
        set { setList(newValue, forKey: "userReminderLists") }
    }

    private func getList(forKey key: String) -> [ListInfo] {
        guard let data = UserDefaults.standard.data(forKey: key),
        let list = try? JSONDecoder().decode([ListInfo].self, from: data) else { return [] }
        return list
    }

    private func setList(_ list: [ListInfo], forKey key: String) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    
    // MARK: - 周报

    private static var sandboxReportDirectory: String {
        (NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? "/tmp")
            .appending("/AutoPlan/Reports")
    }

    var reportDirectory: String = UserDefaults.standard.string(forKey: "reportDirectory") ?? AppSettings.sandboxReportDirectory {
        didSet {
            UserDefaults.standard.set(reportDirectory, forKey: "reportDirectory")
        }
    }

    /// 一周的第一天：1=Sunday, 2=Monday（默认周一）
    var firstWeekday: Int = UserDefaults.standard.object(forKey: "firstWeekday") as? Int ?? 2 {
        didSet {
            UserDefaults.standard.set(firstWeekday, forKey: "firstWeekday")
        }
    }

    /// 周报关注的日历列表 ID（有序）
    var reportFocusedEventList: [String] = UserDefaults.standard.stringArray(forKey: "reportFocusedEventList") ?? [] {
        didSet {
            UserDefaults.standard.set(reportFocusedEventList, forKey: "reportFocusedEventList")
        }
    }

    /// 周报关注的提醒事项列表 ID（有序）
    var reportFocusedReminderList: [String] = UserDefaults.standard.stringArray(forKey: "reportFocusedReminderList") ?? [] {
        didSet {
            UserDefaults.standard.set(reportFocusedReminderList, forKey: "reportFocusedReminderList")
        }
    }

    // MARK: - 复杂类型 (Enum)
    enum AppTheme: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: Self { self }
    }
    
    
    
    // MARK: - 用户偏好分类
    
}


