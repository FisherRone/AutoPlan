import Testing
import SwiftUI
import AutoPlanCore      // 同包内直接 import，无需 @testable

@MainActor
struct TimeSheetBarExportTests {
    @Test func exportLastWeekPNG() {
        let events = TimeSheetData.lastWeek
        let view = TimeSheetBar(events: events, firstWeekday: 2)
        let size = CGSize(width: 600, height: 400)

        let data = renderViewToPNG(view, size: size)
        #expect(data != nil, "PNG 导出失败，renderViewToPNG 返回 nil")

        // 可选：写文件到临时目录方便肉眼检查
        if let data {
            let url = URL(fileURLWithPath: "/tmp/TimeSheetBar_test.png")
            try? data.write(to: url)
            print("✅ PNG written to \(url.path)")
        }
    }
}
