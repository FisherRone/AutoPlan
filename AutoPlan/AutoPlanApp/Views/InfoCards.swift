//
//  InfoCards.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/29.
//

import SwiftUI
import AutoPlanCore
import OSLog
import os.log



struct InfoCardConfigs {
    let iconSize: Int = 17
    let iconBackgroundSize: Int = 8
    let inLineIconSize: Int = 10
}

// MARK: - 1. Event Component
struct EventCard: View {
    let title: String
    var location: String = ""
    var url: String = ""
    let categoryColor: Color
    var listName: String? = nil
    var iconName: String

    let topRightText: String
    let bottomRightText: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 左侧垂直细条
            Capsule()
                .fill(categoryColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
            
            // 2. 左侧信息区 (左对齐)
            VStack(alignment: .leading, spacing: 4) {
                // 第 1 行：标题 (黑色/Primary)
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                // 第 2 行：图标和信息
                HStack(spacing: 4) {
                    // 列表名称
                    if let list = listName {
                        let icon = iconName
                        Image(systemName: icon)
                            .font(.caption)
                        Text(list)
                            .font(.caption)
                    }
                    
                    // 优先展示地点
                    if !location.isEmpty {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(location)
                            .font(.caption)
                    }
                    // 没有地点再展示 url 或视频会议
                    if location.isEmpty && !url.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: url.isMeetingLink() ? "video.fill" : "link")
                                .font(.caption)
                            Text(url)
                                .font(.caption)
                        }
                    }
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)
                
                
                
            }
            
            Spacer()
            
            // 3. 右侧信息区 (右对齐)
            VStack(alignment: .trailing, spacing: 4) {
                // 第一行：开始时间 (黑色/Primary)
                Text(topRightText)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .monospacedDigit()  // 数字等宽，防止时间跳动
                
                // 第二行：结束时间 (灰色/Secondary)
                Text(bottomRightText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
    }
}

// MARK: - 2. Reminder Card
struct ReminderCard: View {
    let title: String
    let rightText: String
    let categoryColor: Color
    let listName: String? = nil
    var iconName: String
    
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 左侧圆圈 (静态视觉元素)
            ZStack {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 17, height: 17)
                
                Image(systemName: iconName)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            }
            
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer()
            
            Text(rightText)
                .font(.caption)
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
    }
}

// MARK: - 3. All Day
struct AllDayCard: View {
    let title: String
    let rightText: String
    let categoryColor: Color
    var iconName: String
    
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 左侧实心圆 + 图标
            ZStack {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 17, height: 17)
                let icon = iconName
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            }
            
            // 2. 标题 (黑色/Primary)
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // 3. 右侧文本 (黑色/Primary)
            Text(rightText)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - EventItem Initializers

extension EventCard {
    init(event: EventItem) {
        self.title = event.title
        self.location = event.location ?? ""
        self.url = event.meetingLink ?? event.url ?? ""
        self.categoryColor = {
            if let colorHex = event.listInfo?.colorHex {
                return Color(hex: colorHex)
            }
            return .blue
        }()
        if let list = event.listInfo {
            self.listName = list.name
        }
        
        self.iconName = event.listInfo?.iconName ?? "calendar"
                
        let formatter = DateFormatter()
        if let start = event.startTime {
            formatter.dateFormat = "HH:mm"
            self.topRightText = formatter.string(from: start)
        } else {
            self.topRightText = "日程"
        }
        
        if let end = event.endTime {
            formatter.dateFormat = "HH:mm"
            self.bottomRightText = formatter.string(from: end)
        } else {
            self.bottomRightText = ""
        }
    }
}

extension ReminderCard {
    init(event: EventItem) {
        self.title = event.title
        self.categoryColor = {
            if let colorHex = event.listInfo?.colorHex {
                return Color(hex: colorHex)
            }
            return .blue
        }()
        
        self.iconName = event.listInfo?.iconName ?? "checkmark"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        if let time = event.reminderTime ?? event.startTime {
            self.rightText = formatter.string(from: time)
        } else {
            self.rightText = "提醒"
        }
    }
}

extension AllDayCard {
    init(event: EventItem) {
        self.title = event.title
        self.categoryColor = {
            if let colorHex = event.listInfo?.colorHex {
                return Color(hex: colorHex)
            }
            return .blue
        }()
        self.rightText = "全天"
        if let list = event.listInfo {
            self.iconName = list.iconName
        }
        self.iconName = event.listInfo?.iconName ?? "calendar"
    }
}

#Preview("Layout Check") {
    VStack(spacing: 8) {
        
        // 分组 1: Events
        Group {
            Text("Events").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top)
            
            EventCard(
                title: "人工智能导论",
                location: "教书院 226",
                categoryColor: .blue,
                iconName: "book",
                topRightText: "18:00",
                bottomRightText: "20:25",
                
            )
            Divider()
            EventCard(
                title: "抽样调查",
                url: "腾讯会议: 222-222-222",
                categoryColor: .orange,
                iconName: "book",
                topRightText: "13:00",
                bottomRightText: "16:25"
            )
            Divider()
            EventCard(
                title: "抽样调查",
                categoryColor: .orange,
                iconName: "book",
                topRightText: "13:00",
                bottomRightText: "16:25"
            )
            Divider()
            EventCard(
                title: "超长的文本咻咻咻嘻嘻嘻嘻嘻像小星星像小星星",
                categoryColor: .yellow,
                iconName: "checkmark",
                topRightText: "13:00",
                bottomRightText: "16:25"
            )
        }
        
        // 分组 2: Reminders
        Group {
            Text("Reminders").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top)
            
            ReminderCard(
                title: "提交开题报告",
                rightText: "08:30",
                categoryColor: .red,
                iconName: "book"
            )
            Divider()
            ReminderCard(
                title: "去超市买菜修须有胡秀华会后会又秀有 iuiu",
                rightText: "18:00",
                categoryColor: .green,
                iconName: "house"
            )
        }
        
        // 分组 3: All Day
        Group {
            Text("All Day").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top)
            
            AllDayCard(
                title: "本周目标",
                rightText: "全天",
                categoryColor: .pink,
                iconName: "checkmark"
            )
            Divider()
            AllDayCard(
                title: "因果推断阅读报告",
                rightText: "截止",
                categoryColor: .purple,
                iconName: "book"
            )
        }
    }
    .padding()
    // 模拟一个常见的卡片背景容器
    .background(Color("ChatBackground")) // macOS/iOS 适配背景
}
