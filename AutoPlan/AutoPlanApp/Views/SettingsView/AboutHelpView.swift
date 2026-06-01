//
//  AboutHelpView.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/10.
//


import SwiftUI
import AppKit

struct AboutHelpView: View {
    @State private var showCopiedToast = false
    @State private var isHovering = false
    
    // 从 Bundle 获取 App 信息
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "AutoPlan"
    }
    
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private var appIcon: NSImage? {
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns") {
            return NSImage(contentsOfFile: iconPath)
        }
        return NSImage(named: "AppIcon") ?? NSImage(named: NSImage.applicationIconName)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部图标与名称
            VStack(spacing: 12) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .shadow(radius: 2)
                } else {
                    Image(systemName: "calendar.badge.clock")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(.accentColor)
                }
                
                Text(appName)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                
                Text("版本 \(appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, 40)
            
            // 帮助说明
            Form {
                Section(header: Text("使用帮助")) {
                    VStack(alignment: .leading) {
                        Text("本 App 的作用")
                        Text("从文本或图片中提取日程，并保存到系统日历。")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("如何提取日程")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. 截图保存至剪贴板，或复制文本到剪贴板")
                            Text("2. 点击菜单栏上的 App 图标")
                            Text("3. 点击“从剪贴板提取日程”")
                        }
                        .font(.callout).foregroundStyle(.secondary)
                    }
                    
                    HStack(alignment: .top) {
                        Text("试一试：")
                        Button {
                            copyToClipboard(String(localized: "@猫猫 刚收到通知，下周三之前要把客户满意度调查结果整理成Excel发给我，记得加上环比数据。还有那个合同扫描件也尽快传一下，谢啦。"))
                        } label: {
                            Text("@猫猫 刚收到通知，下周三之前要把客户满意度调查结果整理成Excel发给我，记得加上环比数据。还有那个合同扫描件也尽快传一下，谢啦。")
                                .font(.callout)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(isHovering ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isHovering = hovering
                            }
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .overlay {
                            if showCopiedToast {
                                Text("已复制")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 20)
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedToast = false
            }
        }
    }
}



#Preview {
    AboutHelpView()
}
