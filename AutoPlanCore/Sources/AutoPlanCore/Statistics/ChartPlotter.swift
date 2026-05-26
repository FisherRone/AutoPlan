import SwiftUI
import AppKit
import Charts

/// 将任意 SwiftUI 视图（比如 Chart）渲染为 PNG
/// - Parameters:
///   - view: 要渲染的视图（可以是 Chart 或包含 Chart 的任意 View）
///   - size: 渲染尺寸（建议明确指定，避免空白）
///   - scale: 缩放比例，默认 3.0（Retina 清晰度）
/// - Returns: Data 或 nil（渲染失败时）
@MainActor
public func renderViewToPNG(
    _ view: some View,
    size: CGSize,
    scale: CGFloat = 3.0
) -> Data? {
    let fixedView = view.frame(width: size.width, height: size.height)
    let renderer = ImageRenderer(content: fixedView)
    renderer.scale = scale
    guard let cgImage = renderer.cgImage else { return nil }
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    // bitmap 尺寸自动从 cgImage 继承，不需要手动设置
    return bitmap.representation(using: .png, properties: [:])
}
