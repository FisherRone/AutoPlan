//
//  ColorToHex.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/25.
//
import SwiftUI
import Foundation

extension CGColor {
    // 使用 nonisolated 关键字，表示这个方法不属于任何 Actor，可以在任何线程运行
    nonisolated func toHex() -> String {
        guard let components = components, components.count >= 3 else { return "#000000" }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
