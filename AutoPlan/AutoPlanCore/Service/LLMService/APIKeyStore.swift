//
//  APIKeyStore.swift
//  AutoPlanCore
//
//  Created by 荣子鱼 on 2026/5/23.
//

import Foundation
import Security

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
              let data = result as? Data,
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    /// 向 Keychain 写入所有 API Keys
    private static func writeAll(_ dict: [String: String]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
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
    }

    /// 保存某个 provider 的 API Key
    public static func save(for providerID: String, value: String) {
        var dict = readAll()
        dict[providerID] = value
        writeAll(dict)
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
