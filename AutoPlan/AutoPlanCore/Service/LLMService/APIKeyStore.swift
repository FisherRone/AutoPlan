//
//  APIKeyStore.swift
//  AutoPlanCore
//
//  Created by 荣子鱼 on 2026/5/23.
//

import Foundation
import Security
import SwiftyBeaver

enum APIKeyStoreWarning {
    case readDecodingFailed
    case writeEncodingFailed
    
    var message: WarningMessage {
        switch self {
        case .readDecodingFailed:
            return WarningMessage(
                id: "apiKeyStore.readDecodingFailed",
                severity: .error,
                logText: "APIKeyStore: failed to decode stored keys from Keychain"
            )
        case .writeEncodingFailed:
            return WarningMessage(
                id: "apiKeyStore.writeEncodingFailed",
                severity: .error,
                logText: "APIKeyStore: failed to encode keys for Keychain write"
            )
        }
    }
}

/// 使用 Keychain 存储 API Key，所有 Key 保存在一个条目中。
public enum APIKeyStore {

    private static let keychainService = "com.autoplan.apikeys"
    private static let keychainAccount = "all_api_keys"

    /// 从 Keychain 读取所有 API Keys
    private static func readAll() -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else {
            return [:]
        }
        guard let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            APIKeyStoreWarning.readDecodingFailed.message.log()
            return [:]
        }
        return dict
    }

    /// 向 Keychain 写入所有 API Keys
    @discardableResult
    private static func writeAll(_ dict: [String: String]) -> Bool {
        guard let data = try? JSONEncoder().encode(dict) else {
            APIKeyStoreWarning.writeEncodingFailed.message.log()
            return false
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let updateAttributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
        return true
    }

    @discardableResult
    public static func save(for providerID: String, value: String) -> Bool {
        var dict = readAll()
        dict[providerID] = value
        return writeAll(dict)
    }

    /// 读取某个 provider 的 API Key
    public static func read(for providerID: String) -> String? {
        readAll()[providerID]
    }

    /// 删除某个 provider 的 API Key
    public static func delete(for providerID: String) {
        var dict = readAll()
        dict.removeValue(forKey: providerID)
        writeAll(dict)
    }
}
