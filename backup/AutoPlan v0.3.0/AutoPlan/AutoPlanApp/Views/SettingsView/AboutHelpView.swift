//
//  AboutHelpView.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/10.
//


import SwiftUI
import AppKit

struct AboutHelpView: View {
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
                    LabeledContent("本 App 的作用") {
                        Text("从文本或图片中提取日程，并保存到系统日历。")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    /*
                    LabeledContent("安装快捷指令") {
                        HStack(spacing: 4) {
                            InstallShortcutButton(shortcutName: "安装提取日程")
                            InstallShortcutButton(shortcutName: "安装撰写周报")
                        }
                    }
                    */
                    
                    LabeledContent("如何提取日程") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. 截图保存至剪贴板，或复制文本到剪贴板")
                            Text("2. 点击菜单栏上的 App 图标")
                            Text("3. 点击“从剪贴板提取日程”")
                        }
                        .font(.callout)
                    }
                    
                    LabeledContent("如何撰写周报") {
                        VStack(alignment: .leading, spacing: 4) {
                            //Text("1. 运行“撰写周报”快捷指令，即可撰写并保存到指定目录")
                            //Text("2. 您可以创建一个快捷指令自动化，实现每周自动撰写")
                            Text("1. 点击菜单栏上的 App 图标")
                            Text("2. 点击“生成周报”")
                        }
                        .font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 20)
        }
    }
    
    private func openShortcutsApp() {
        // macOS 快捷指令 App 的 Bundle ID
        let shortcutsBundleID = "com.apple.shortcuts"
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: shortcutsBundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            // 未安装快捷指令时的后备提示
            let alert = NSAlert()
            alert.messageText = "未找到快捷指令 App"
            alert.informativeText = "请确保您的 macOS 版本支持快捷指令。"
            alert.runModal()
        }
    }
}

struct InstallShortcutButton: View {
    let shortcutName: String // 添加属性
    
    var body: some View {
        Button(shortcutName) {
            installFromBundle(shortcutName: shortcutName)
        }
    }
    
    private func installFromBundle(shortcutName: String) {
        guard let fileURL = Bundle.main.url(forResource: shortcutName, withExtension: "shortcut") else {
            print("❌ 未找到内嵌的 .shortcut 文件")
            return
        }

        if let shortcutApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") {
            NSWorkspace.shared.open([fileURL], withApplicationAt: shortcutApp, configuration: .init()) { app, error in
                if let error = error {
                    print("❌ 打开失败: \(error.localizedDescription)")
                }
            }
        } else {
            print("❌ 未找到“快捷指令”App")
        }
    }
}

#Preview {
    AboutHelpView()
}
