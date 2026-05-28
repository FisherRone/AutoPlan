import Cocoa
import SwiftUI
import AutoPlanCore
import OSLog

nonisolated private let appLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AutoPlan", category: "AppDelegate")

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()
    }
}

// MARK: - Menu Bar Controller

final class MenuBarController: NSObject {
    private static let menuIcon = "calendar.badge.plus"

    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    private lazy var settingsWindowController = AutoPlanSettingsWindowController()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        setupStatusItem()
        setupPopover()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: Self.menuIcon, accessibilityDescription: "AutoPlan")
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "设置...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let extractItem = NSMenuItem(
            title: "从剪贴板提取日程",
            action: #selector(extractFromClipboard),
            keyEquivalent: ""
        )
        extractItem.target = self
        menu.addItem(extractItem)

        menu.addItem(.separator())

        let reportItem = NSMenuItem(
            title: "生成周报",
            action: #selector(generateWeeklyReport),
            keyEquivalent: ""
        )
        reportItem.target = self
        menu.addItem(reportItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 AutoPlan",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func setupPopover() {
        popover.behavior = .applicationDefined
    }

    // MARK: - Icon State

    private func updateIcon(isLoading: Bool) {
        guard let button = statusItem.button else { return }

        if isLoading {
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "处理中...")
        } else {
            button.image = NSImage(systemSymbolName: Self.menuIcon, accessibilityDescription: "AutoPlan")
        }
    }

    // MARK: - Actions

    @objc private func openSettings() {
        statusItem.menu?.cancelTracking()
        settingsWindowController.show()
    }

    @objc private func extractFromClipboard() {
        statusItem.menu?.cancelTracking()

        let pasteboard = NSPasteboard.general
        let clipboardText = pasteboard.string(forType: .string) ?? ""

        let imageObjects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] ?? []
        let cgImages: [CGImage] = imageObjects.compactMap { nsImage in
            nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }

        guard !clipboardText.isEmpty || !cgImages.isEmpty else {
            showErrorPopover(message: "剪贴板中没有可识别的文本或图片。")
            return
        }

        Task {
            await MainActor.run { updateIcon(isLoading: true) }

            do {
                let events = try await AutoPlanEngine.process(
                    clipboardText,
                    cgImages: cgImages.isEmpty ? nil : cgImages
                )
                guard !events.isEmpty else {
                    showErrorPopover(message: "未识别到任何日程或提醒事项。")
                    return
                }

                if AppSettings.shared.directSave {
                    let selected = events.filter(\.isSelected)
                    guard !selected.isEmpty else {
                        await MainActor.run { updateIcon(isLoading: false) }
                        return
                    }
                    do {
                        let (_, savedEvents) = try await AutoPlanEngine.saveItems(selected)
                        showSavedPopover(events: savedEvents)
                    } catch {
                        appLogger.error("❌ 保存失败: \(error.localizedDescription)")
                        showErrorPopover(message: "保存失败: \(error.localizedDescription)")
                    }
                } else {
                    showPreviewPopover(events: events)
                }
            } catch AutoPlanError.noItemsRecognized {
                showErrorPopover(message: "未识别到任何日程或提醒事项。")
            } catch {
                appLogger.error("❌ 提取失败: \(error.localizedDescription)")
                showErrorPopover(message: "提取失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Popover Helpers

    /// 预览确认弹窗（用户操作关闭）
    private func showPreviewPopover(events: [EventItem]) {
        popover.contentViewController = NSHostingController(
            rootView: MenuBarEventPopoverView(
                mode: .preview(events: events),
                onDismiss: { [weak self] in self?.popover.performClose(nil) },
                onSave: { [weak self] eventsToSave in
                    let selected = eventsToSave.filter(\.isSelected)
                    guard !selected.isEmpty else {
                        self?.popover.performClose(nil)
                        return
                    }
                    do {
                        let (_, savedEvents) = try await AutoPlanEngine.saveItems(selected)
                        await MainActor.run {
                            self?.showSavedPopover(events: savedEvents)
                        }
                    } catch {
                        appLogger.error("❌ 保存失败: \(error.localizedDescription)")
                        await MainActor.run {
                            self?.showErrorPopover(message: "保存失败: \(error.localizedDescription)")
                        }
                    }
                }
            )
        )
        showPopover(behavior: .applicationDefined)
    }

    /// 成功保存弹窗（点外部或 3 秒自动关闭）
    private func showSavedPopover(events: [EventItem]) {
        popover.contentViewController = NSHostingController(
            rootView: MenuBarEventPopoverView(
                mode: .saved(events),
                onDismiss: { [weak self] in self?.popover.performClose(nil) }
            )
        )
        showPopover(behavior: .transient, autoDismissAfter: 3)
    }

    /// 错误提示弹窗（点外部或 3 秒自动关闭）
    private func showErrorPopover(message: String) {
        popover.contentViewController = NSHostingController(
            rootView: ErrorSnippetView(message: message)
        )
        showPopover(behavior: .transient, autoDismissAfter: 3)
    }

    private func showPopover(behavior: NSPopover.Behavior, autoDismissAfter seconds: TimeInterval? = nil) {
        updateIcon(isLoading: false)
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        }

        // Defer to next run loop to avoid calling popover.show during an active layout pass, which triggers AppKit layout recursion
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            self.popover.behavior = behavior
            self.popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .maxY
            )

            if let seconds {
                DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                    self?.popover.performClose(nil)
                }
            }
        }
    }

    // MARK: - Weekly Report

    @objc private func generateWeeklyReport() {
        statusItem.menu?.cancelTracking()

        Task {
            await MainActor.run { updateIcon(isLoading: true) }

            do {
                let config = try await ListStore.refresh()
                try await ReportWriter.writeWeeklyReport(
                    date: Date(),
                    config: config
                )

                let appSupport = NSSearchPathForDirectoriesInDomains(
                    .applicationSupportDirectory, .userDomainMask, true
                ).first ?? "/tmp"
                let dirPath = (appSupport as NSString).appendingPathComponent("AutoPlan/Reports")

                await MainActor.run {
                    showWeeklyReportGeneratedPopover(directoryPath: dirPath)
                }
            } catch {
                appLogger.error("❌ 周报生成失败: \(error.localizedDescription)")
                await MainActor.run {
                    showErrorPopover(message: "周报生成失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showWeeklyReportGeneratedPopover(directoryPath: String) {
        popover.contentViewController = NSHostingController(
            rootView: MenuBarEventPopoverView(
                mode: .weeklyReportGenerated(directoryPath: directoryPath),
                onDismiss: { [weak self] in self?.popover.performClose(nil) }
            )
        )
        showPopover(behavior: .applicationDefined)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
