import Cocoa
import SwiftUI
import SwiftyBeaver

final class AutoPlanSettingsWindowController: NSWindowController {

    init() {
        logger.debug("🪟 AutoPlanSettingsWindowController init 开始", context: "SettingsWindow")
        let hostingController = NSHostingController(rootView: SettingsTabView())
        logger.debug("🪟 NSHostingController 已创建", context: "SettingsWindow")

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
        logger.debug("🪟 NSWindow 已创建", context: "SettingsWindow")

        super.init(window: window)
        logger.debug("🪟 AutoPlanSettingsWindowController init 完成, window=(String(describing: self.window))", context: "SettingsWindow")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Bring the window to front, creating it if necessary.
    func show() {
        logger.debug("🪟 show() 被调用", context: "SettingsWindow")
        guard let window else {
            logger.error("🪟 window 为 nil!", context: "SettingsWindow")
            return
        }
        logger.debug("🪟 window.isVisible=(window.isVisible), window.isMiniaturized=(window.isMiniaturized)", context: "SettingsWindow")
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        logger.debug("🪟 即将调用 showWindow", context: "SettingsWindow")
        showWindow(nil)
        logger.debug("🪟 showWindow 完成, 即将调用 makeKeyAndOrderFront", context: "SettingsWindow")
        window.makeKeyAndOrderFront(nil)
        logger.debug("🪟 makeKeyAndOrderFront 完成, window.isVisible=(window.isVisible)", context: "SettingsWindow")
    }
}

// MARK: - Settings Tab View (extracted from the original Window scene)

struct SettingsTabView: View {
    @State private var extractorViewModel = ExtractorViewModel(service: RealListManager())
    
    var body: some View {
        TabView {
            Tab("通用", systemImage: "gearshape") {
                ModelConfigView()
            }

            Tab("高级", systemImage: "slider.horizontal.3") {
                ExtractorView(viewModel: extractorViewModel)
            }

            Tab("关于", systemImage: "info.circle") {
                AboutHelpView()
            }
        }
        .frame(minWidth: 580, idealWidth: 580, minHeight: 520, idealHeight: 520)
    }
}
