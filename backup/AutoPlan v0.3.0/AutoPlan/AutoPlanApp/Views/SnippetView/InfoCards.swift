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



enum InfoCardStyle {
    // 原有间距和尺寸
    static let spacing: CGFloat = 6
    static let innerSpacing: CGFloat = 4
    static let capsuleWidth: CGFloat = 3
    static let indicatorSize: CGFloat = 16
    static let indicatorIconSize: CGFloat = 9
    static let circleLineWidth: CGFloat = 2.5

    // 新增：文字样式
    static let titleFont: Font = .system(.body, weight: .medium)

    static let secondaryFont: Font = .body

    static let timeFont: Font = .body
    static let timeWeight: Font.Weight? = nil   // .regular

    static let primaryColor: Color = .primary
    static let secondaryColor: Color = .secondary

    // 是否使用等宽数字 (时间)
    static let useMonospacedDigit: Bool = true
}

// MARK: - MonospacedDigit Conditional Helper

extension View {
    @ViewBuilder
    fileprivate func monospacedDigitIf(_ active: Bool) -> some View {
        if active {
            monospacedDigit()
        } else {
            self
        }
    }
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
        HStack(spacing: InfoCardStyle.spacing) {
            // 1. 左侧垂直细条
            Color.clear
                .frame(width: 16)
                .frame(maxHeight: .infinity)   // 透明容器，宽度固定16，高度随父视图填满
                .overlay(
                    Capsule()
                        .fill(categoryColor)
                        .frame(width: InfoCardStyle.capsuleWidth)
                        .frame(maxHeight: .infinity)
                )
            
            // 2. 左侧信息区 (左对齐)
            VStack(alignment: .leading, spacing: InfoCardStyle.innerSpacing) {
                // 第 1 行：标题
                Text(title)
                    .font(InfoCardStyle.titleFont)
                    .foregroundStyle(InfoCardStyle.primaryColor)
                    .lineLimit(1)
                
                // 第 2 行：图标和信息
                HStack(spacing: InfoCardStyle.innerSpacing) {
                    // 列表名称
                    if let list = listName {
                        let icon = iconName
                        Image(systemName: icon)
                            .font(InfoCardStyle.secondaryFont)
                        Text(list)
                            .font(InfoCardStyle.secondaryFont)
                    }
                    
                    // 优先展示地点
                    if !location.isEmpty {
                        Image(systemName: "location.fill")
                            .font(InfoCardStyle.secondaryFont)
                        Text(location)
                            .font(InfoCardStyle.secondaryFont)
                    }
                    // 没有地点再展示 url 或视频会议
                    if location.isEmpty && !url.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: url.isMeetingLink() ? "video.fill" : "link")
                                .font(InfoCardStyle.secondaryFont)
                            Text(url)
                                .font(InfoCardStyle.secondaryFont)
                        }
                    }
                }
                .foregroundStyle(InfoCardStyle.secondaryColor)
                .lineLimit(1)
            }
            
            Spacer()
            
            // 3. 右侧信息区 (右对齐)
            VStack(alignment: .trailing, spacing: InfoCardStyle.innerSpacing) {
                // 第一行：开始时间
                Text(topRightText)
                    .font(InfoCardStyle.timeFont)
                    .fontWeight(InfoCardStyle.timeWeight)
                    .foregroundStyle(InfoCardStyle.primaryColor)
                    .monospacedDigitIf(InfoCardStyle.useMonospacedDigit)
                
                // 第二行：结束时间
                Text(bottomRightText)
                    .font(InfoCardStyle.timeFont)
                    .foregroundStyle(InfoCardStyle.secondaryColor)
                    .monospacedDigitIf(InfoCardStyle.useMonospacedDigit)
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
        HStack(spacing: InfoCardStyle.spacing) {
            // 1. 左侧圆圈 (静态视觉元素)
            ZStack {
                Circle()
                    .strokeBorder(categoryColor, lineWidth: InfoCardStyle.circleLineWidth)
                    .frame(width: InfoCardStyle.indicatorSize, height: InfoCardStyle.indicatorSize)
                
                Image(systemName: iconName)
                    .font(.system(size: InfoCardStyle.indicatorIconSize, weight: .bold))
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            }
            
            Text(title)
                .font(InfoCardStyle.titleFont)
                .foregroundStyle(InfoCardStyle.primaryColor)
                .lineLimit(1)
            
            Spacer()
            
            Text(rightText)
                .font(InfoCardStyle.timeFont)
                .fontWeight(InfoCardStyle.timeWeight)
                .foregroundStyle(InfoCardStyle.primaryColor)
                .monospacedDigitIf(InfoCardStyle.useMonospacedDigit)
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
        HStack(spacing: InfoCardStyle.spacing) {
            // 1. 左侧实心圆 + 图标
            ZStack {
                Circle()
                    .fill(categoryColor)
                    .frame(width: InfoCardStyle.indicatorSize, height: InfoCardStyle.indicatorSize)
                let icon = iconName
                Image(systemName: icon)
                    .font(.system(size: InfoCardStyle.indicatorIconSize, weight: .bold))
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            }
            
            // 2. 标题
            Text(title)
                .font(InfoCardStyle.titleFont)
                .foregroundStyle(InfoCardStyle.primaryColor)
                .lineLimit(1)
            
            Spacer()
            
            // 3. 右侧文本
            Text(rightText)
                .font(InfoCardStyle.timeFont)
                .fontWeight(InfoCardStyle.timeWeight)
                .foregroundStyle(InfoCardStyle.primaryColor)
                .monospacedDigitIf(InfoCardStyle.useMonospacedDigit)
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
            formatter.dateFormat = "MM/dd HH:mm"
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
        if let time = event.reminderTime ?? event.startTime {
            let calendar = Calendar.current
            let comps = calendar.dateComponents([.hour, .minute], from: time)
            if comps.hour == 0 && comps.minute == 0 {
                formatter.dateFormat = "MM/dd"
            } else {
                formatter.dateFormat = "MM/dd HH:mm"
            }
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
        if let start = event.startTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/dd"
            self.rightText = formatter.string(from: start)
        } else {
            self.rightText = "全天"
        }
        self.iconName = event.listInfo?.iconName ?? "calendar"
    }
}

// MARK: - Preview
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
}
