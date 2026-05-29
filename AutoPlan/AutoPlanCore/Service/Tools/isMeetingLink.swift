//
//  CheckMeetingUrl.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/30.
//

import Foundation

extension String {
    /// 检查字符串是否包含主流视频会议软件名称
    public func isMeetingLink() -> Bool {
        // 定义需要匹配的关键词列表（涵盖中英文）
        let meetingApps = [
            "腾讯会议", "Tencent Meeting", "VooV",
            "钉钉", "DingTalk",
            "飞书", "Lark",
            "Zoom",
            "Teams",
            "Google Meet", "Hangouts",
            "Skype",
            "Webex"
        ]
        
        for app in meetingApps {
            if self.range(of: app, options: .caseInsensitive) != nil {
                return true
            }
        }
        
        return false
    }
}
