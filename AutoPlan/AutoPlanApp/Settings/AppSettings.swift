//
//  Source/AutoPlanApp/Settings/AppSettings.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/18.
//

import SwiftUI
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
    
    var userPrompt: String = UserDefaults.standard.string(forKey: "userPrompt") ?? "" {
        didSet {
            UserDefaults.standard.set(userPrompt, forKey: "userPrompt")
        }
    }
    
    var userInstruction: String = UserDefaults.standard.string(forKey: "userInstruction") ?? "" {
        didSet {
            UserDefaults.standard.set(userInstruction, forKey: "userInstruction")
        }
    }
    
    var useTags: Bool = UserDefaults.standard.bool(forKey: "useTags") {
        didSet {
            UserDefaults.standard.set(useTags, forKey: "useTags")
        }
    }
    
    // MARK: - 弹窗提取
    
    /// 从菜单栏提取日程时，是否需要确认后再保存
    var needsConfirmation: Bool = UserDefaults.standard.object(forKey: "needsConfirmation") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(needsConfirmation, forKey: "needsConfirmation")
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
    
    


    /// 一周的第一天：1=Sunday, 2=Monday（默认周一）
    var firstWeekday: Int = UserDefaults.standard.object(forKey: "firstWeekday") as? Int ?? 2 {
        didSet {
            UserDefaults.standard.set(firstWeekday, forKey: "firstWeekday")
        }
    }


    // MARK: - 复杂类型 (Enum)
    enum AppTheme: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: Self { self }
    }
    
    
    
    // MARK: - 用户偏好分类
    
}


