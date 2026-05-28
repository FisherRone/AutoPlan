//
//  PhotoFile.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2025/12/22.
//


import Foundation


// MARK: - 基础枚举与结构体

enum ContextType: String, Codable, Sendable {
    case settings
    case prompt
    case image
    case document // docx, ppt, etc.
    case webpage
    case event
    case reminder
}



