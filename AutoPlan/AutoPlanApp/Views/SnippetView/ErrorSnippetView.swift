//
//  ErrorSnippetView.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/29.
//


import OSLog
import SwiftUI

// MARK: - 错误展示视图（简单示例）
/// 用于展示错误信息的 Snippet View
struct ErrorSnippetView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
