import Foundation
import Vision

// MARK: - OCR 配置项
/// 定义识别行为的配置参数，移出函数体以便维护和复用
struct OCRConfiguration {
    /// 识别精度等级：
    /// .accurate - 慢但在复杂背景下更准（使用深度学习模型）
    /// .fast - 快但精度稍低（使用传统算法）
    let recognitionLevel: VNRequestTextRecognitionLevel
    
    /// 是否使用语言模型进行自动更正（例如根据上下文修正拼写）
    let usesLanguageCorrection: Bool
    
    /// 优先识别的语言列表（如 ["zh-Hans", "en-US"]）
    /// 留空则系统自动推断
    let recognitionLanguages: [String]
    
    /// 默认配置：高精度、开启纠错、中英文支持
    nonisolated static let `default` = OCRConfiguration(
        recognitionLevel: .accurate,
        usesLanguageCorrection: true,
        recognitionLanguages: ["zh-Hans", "en-US"]
    )
}

// MARK: - 图像 OCR 服务
enum OCRError: Error {
    case processingFailed(String)
    case noTextFound
}

/// 核心识别函数
/// - Parameters:
///   - cgImage: 图片数据
///   - config: 识别配置项
/// - Returns: 识别到的完整字符串
/// 更加简洁、现代的实现
nonisolated func ocr(
    cgImage: CGImage,
    config: OCRConfiguration = .default
) async throws -> String {
    
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = config.recognitionLevel
    request.usesLanguageCorrection = config.usesLanguageCorrection
    request.recognitionLanguages = config.recognitionLanguages
    
    // 2. 执行处理
    // 此时函数运行在 Swift 并发线程池中，而不是主线程（除非调用者强制它在 MainActor 运行）
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    
    // perform 是阻塞操作，但在 async 函数内部，它会阻塞当前的后台线程
    try handler.perform([request])
    
    // 3. 结果提取
    guard let observations = request.results, !observations.isEmpty else {
        throw OCRError.noTextFound
    }
    
    return observations
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
}

