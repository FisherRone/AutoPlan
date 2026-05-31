//
//  ListStore.swift
//  AutoPlan
//
//  Created by 荣子鱼 on 2026/5/10.
//

import Foundation
import os
import SwiftyBeaver

// MARK: - 用户对单个列表的设置

struct ListUserSettings: Codable, Sendable {
    var prompt: String?
    var neglected: Bool
    var source: ListSource?

    nonisolated init(prompt: String? = nil, neglected: Bool = false, source: ListSource? = nil) {
        self.prompt = prompt
        self.neglected = neglected
        self.source = source
    }
}

// MARK: - 列表持久化与合并

public struct ListStore {

    nonisolated private static let storageKey = "ListUserSettings"
    nonisolated private static let iconMappingKey = "UserIconMapping"
    private static let lock = OSAllocatedUnfairLock()

    // MARK: - 读取持久化设置

    nonisolated static func loadSettings() -> [String: ListUserSettings] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: ListUserSettings].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    // MARK: - 写入持久化设置

    nonisolated static func saveSettings(_ settings: [String: ListUserSettings]) {
        guard let data = try? JSONEncoder().encode(settings) else {
            logger.error("Failed to encode ListUserSettings", context: "ListStore")
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - 更新单个列表设置

    public static func updateSettings(
        for listId: String,
        prompt: String? = nil,
        neglected: Bool? = nil,
        source: ListSource? = nil
    ) {
        lock.withLock {
            var settings = loadSettings()
            var current = settings[listId] ?? ListUserSettings()
            if let p = prompt { current.prompt = p.isEmpty ? nil : p }
            if let n = neglected { current.neglected = n }
            if let s = source { current.source = s }
            settings[listId] = current
            saveSettings(settings)
        }
    }

    // MARK: - 用户图标映射（keyword → iconName）

    nonisolated static func loadUserIconMapping() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: iconMappingKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    nonisolated private static func saveUserIconMapping(_ mapping: [String: String]) {
        guard let data = try? JSONEncoder().encode(mapping) else {
            logger.error("Failed to encode UserIconMapping", context: "ListStore")
            return
        }
        UserDefaults.standard.set(data, forKey: iconMappingKey)
    }

    public static func setUserIcon(keyword: String, iconName: String) {
        lock.withLock {
            var mapping = loadUserIconMapping()
            mapping[keyword] = iconName
            saveUserIconMapping(mapping)
        }
    }

    // MARK: - 合并系统列表与用户设置

    /// 将系统获取的列表与用户持久化设置合并
    /// - 新系统列表 → 加入合并结果，默认设置
    /// - 已存在系统列表 → 合并用户 prompt / neglected
    /// - 失效但有 prompt 的列表 → 保留为 unavailable
    /// - 失效且无 prompt 的列表 → 丢弃
    static func merge(
        systemCalendars: [ListInfo],
        systemReminders: [ListInfo]
    ) -> (calendars: [ListInfo], reminders: [ListInfo]) {
        let settings = lock.withLock { () -> [String: ListUserSettings] in
            var settings = loadSettings()
            let allSystemIds = Set(systemCalendars.map(\.id) + systemReminders.map(\.id))

            // 清理失效且无 prompt 的 settings
            let staleToRemove = settings.filter { id, user in
                !allSystemIds.contains(id) && (user.prompt == nil || user.prompt!.isEmpty)
            }
            for id in staleToRemove.keys {
                settings.removeValue(forKey: id)
            }
            if !staleToRemove.isEmpty {
                saveSettings(settings)
                logger.info("清理了 \(staleToRemove.count) 条失效且无描述的列表设置", context: "ListStore")
            }
            return settings
        }

        let mergedCalendars = mergeInto(systemLists: systemCalendars, settings: settings, source: .calendar)
        let mergedReminders = mergeInto(systemLists: systemReminders, settings: settings, source: .reminders)

        return (mergedCalendars, mergedReminders)
    }

    private static func mergeInto(
        systemLists: [ListInfo],
        settings: [String: ListUserSettings],
        source: ListSource
    ) -> [ListInfo] {
        // 1. 系统可用列表 → 合并用户设置
        var merged: [ListInfo] = systemLists.map { sys in
            let user = settings[sys.id]
            return ListInfo(
                id: sys.id,
                name: sys.name,
                colorHex: sys.colorHex,
                available: true,
                source: source,
                prompt: user?.prompt,
                neglected: user?.neglected ?? false,
                iconName: ListInfo.iconName(for: sys.name, source: source)
            )
        }

        // 2. 失效但有 prompt 的列表 → 保留为 unavailable
        let systemIds = Set(systemLists.map(\.id))
        for (id, user) in settings {
            guard !systemIds.contains(id),
                  let prompt = user.prompt, !prompt.isEmpty,
                  user.source == source
            else { continue }

            merged.append(ListInfo(
                id: id,
                name: id, // 失效列表用 id 作为 name 兜底
                colorHex: "#999999",
                available: false,
                source: source,
                prompt: prompt,
                neglected: user.neglected,
                iconName: ListInfo.iconName(for: id, source: source)
            ))
        }

        return merged
    }

    // MARK: - 刷新：获取系统列表并合并用户设置

    public static func refresh() async throws -> CoreConfiguration {
        async let systemCalendars = EventService.shared.getWritableCalendars(for: .event)
        async let systemReminders = EventService.shared.getWritableCalendars(for: .reminder)
        let (calendars, reminders) = try await (systemCalendars, systemReminders)

        let (mergedCalendars, mergedReminders) = merge(
            systemCalendars: calendars,
            systemReminders: reminders
        )

        return CoreConfiguration(
            useList: true,
            useTags: false,
            userCalendarLists: mergedCalendars,
            userReminderLists: mergedReminders
        )
    }
}
