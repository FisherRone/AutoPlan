import Cocoa
import SwiftUI
import OSLog

private let settingsLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AutoPlan", category: "SettingsWindow")

final class AutoPlanSettingsWindowController: NSWindowController {

    init() {
        settingsLogger.debug("🪟 AutoPlanSettingsWindowController init 开始")
        let hostingController = NSHostingController(rootView: SettingsTabView())
        settingsLogger.debug("🪟 NSHostingController 已创建")

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AutoPlan 设置"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("AutoPlanSettings")
        settingsLogger.debug("🪟 NSWindow 已创建")

        super.init(window: window)
        settingsLogger.debug("🪟 AutoPlanSettingsWindowController init 完成, window=(String(describing: self.window))")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Bring the window to front, creating it if necessary.
    func show() {
        settingsLogger.debug("🪟 show() 被调用")
        guard let window else {
            settingsLogger.error("🪟 window 为 nil!")
            return
        }
        settingsLogger.debug("🪟 window.isVisible=(window.isVisible), window.isMiniaturized=(window.isMiniaturized)")
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsLogger.debug("🪟 即将调用 showWindow")
        showWindow(nil)
        settingsLogger.debug("🪟 showWindow 完成, 即将调用 makeKeyAndOrderFront")
        window.makeKeyAndOrderFront(nil)
        settingsLogger.debug("🪟 makeKeyAndOrderFront 完成, window.isVisible=(window.isVisible)")
    }
}

// MARK: - Settings Tab View (extracted from the original Window scene)

struct SettingsTabView: View {
    var body: some View {
        TabView {
            Tab("通用", systemImage: "gearshape") {
                ModelConfigView()
            }

            Tab("日程提取", systemImage: "list.bullet") {
                ExtractorView(viewModel: ExtractorViewModel(service: RealListManager()))
            }

            Tab("关于", systemImage: "info.circle") {
                AboutHelpView()
            }
        }
        .frame(minWidth: 540, idealWidth: 540, minHeight: 500, idealHeight: 600)
    }
}
