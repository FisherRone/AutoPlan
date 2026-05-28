import Cocoa
import SwiftUI

final class AutoPlanSettingsWindowController: NSWindowController {

    init() {
        let hostingController = NSHostingController(rootView: SettingsTabView())

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

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Bring the window to front, creating it if necessary.
    func show() {
        guard let window else { return }
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
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
                ExtractorView()
            }

            Tab("关于", systemImage: "info.circle") {
                AboutHelpView()
            }
        }
        .frame(minWidth: 540, idealWidth: 540, minHeight: 500, idealHeight: 600)
    }
}
