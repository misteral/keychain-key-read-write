import Foundation
import Security

enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case invalidData
    case syncUnavailable(OSStatus)

    var description: String {
        switch self {
        case .itemNotFound:
            return "Key not found in keychain"
        case .duplicateItem:
            return "Key already exists in keychain"
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status: \(status)"
        case .invalidData:
            return "Invalid data format"
        case .syncUnavailable(let status):
            return "Synchronizable keychain write is unavailable (status: \(status))"
        }
    }
}

enum StorageMode {
    case synchronizableWithFallback
    case synchronizableOnly
    case localOnly
}

enum SetResult {
    case synchronizable
    case localFallback
    case localOnly
}

struct KeychainItem {
    let key: String
    let value: String
}

struct KeyStatus {
    let key: String
    let isLocal: Bool
    let isSynchronizable: Bool

    var statusLabel: String {
        if isLocal && isSynchronizable {
            return "both"
        }
        if isSynchronizable {
            return "sync"
        }
        return "local"
    }
}

final class KeychainManager {
    private let service: String

    init(service: String = "kc-cli") {
        self.service = service
    }

    func set(key: String, value: String, mode: StorageMode = .synchronizableWithFallback) throws -> SetResult {
        switch mode {
        case .synchronizableOnly:
            try upsertSynchronizable(key: key, value: value)
            return .synchronizable
        case .localOnly:
            try upsertLocal(key: key, value: value)
            return .localOnly
        case .synchronizableWithFallback:
            do {
                try upsertSynchronizable(key: key, value: value)
                return .synchronizable
            } catch KeychainError.syncUnavailable {
                try upsertLocal(key: key, value: value)
                return .localFallback
            }
        }
    }

    func get(key: String) throws -> String {
        if let syncValue = try getSynchronizableIfExists(key: key) {
            return syncValue
        }

        if let localValue = try getLocalIfExists(key: key) {
            return localValue
        }

        throw KeychainError.itemNotFound
    }

    func delete(key: String) throws {
        let deletedSync = try deleteSynchronizableIfExists(key: key)
        let deletedLocal = try deleteLocalIfExists(key: key)

        guard deletedSync || deletedLocal else {
            throw KeychainError.itemNotFound
        }
    }

    func migrateToSync(key: String) throws {
        guard let localValue = try getLocalIfExists(key: key) else {
            throw KeychainError.itemNotFound
        }

        try upsertSynchronizable(key: key, value: localValue)
        _ = try deleteLocalIfExists(key: key)
    }

    func migrateAllLocalItemsToSync() throws -> [String] {
        let items = try listLocalItems()
        var migratedKeys: [String] = []

        for item in items {
            try upsertSynchronizable(key: item.key, value: item.value)
            _ = try deleteLocalIfExists(key: item.key)
            migratedKeys.append(item.key)
        }

        return migratedKeys
    }

    func listLocalItems() throws -> [KeychainItem] {
        let accounts = try listLocalKeys()
        var items: [KeychainItem] = []

        for account in accounts {
            guard let value = try getLocalIfExists(key: account) else {
                continue
            }

            items.append(KeychainItem(key: account, value: value))
        }

        return items.sorted { $0.key < $1.key }
    }

    func listLocalKeys() throws -> [String] {
        try listAccounts(extraQuery: [:])
    }

    func listSynchronizableKeys() throws -> [String] {
        try listAccounts(extraQuery: [kSecAttrSynchronizable as String: kCFBooleanTrue!])
    }

    func listStatuses() throws -> [KeyStatus] {
        let localKeys = Set(try listLocalKeys())
        let syncKeys = Set(try listSynchronizableKeys())
        let allKeys = Array(localKeys.union(syncKeys)).sorted()

        return allKeys.map { key in
            KeyStatus(
                key: key,
                isLocal: localKeys.contains(key),
                isSynchronizable: syncKeys.contains(key)
            )
        }
    }

    private func upsertSynchronizable(key: String, value: String) throws {
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: valueData,
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        if addStatus == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecAttrSynchronizable as String: kCFBooleanTrue!
            ]

            let attributes: [String: Any] = [
                kSecValueData as String: valueData
            ]

            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                if isSyncUnavailable(status: updateStatus) {
                    throw KeychainError.syncUnavailable(updateStatus)
                }
                throw KeychainError.unexpectedStatus(updateStatus)
            }

            return
        }

        if isSyncUnavailable(status: addStatus) {
            throw KeychainError.syncUnavailable(addStatus)
        }

        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    private func upsertLocal(key: String, value: String) throws {
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: valueData
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        if addStatus == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]

            let attributes: [String: Any] = [
                kSecValueData as String: valueData
            ]

            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }

            return
        }

        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    private func getSynchronizableIfExists(key: String) throws -> String? {
        return try getValue(
            key: key,
            extraQuery: [kSecAttrSynchronizable as String: kCFBooleanTrue!]
        )
    }

    private func getLocalIfExists(key: String) throws -> String? {
        return try getValue(key: key, extraQuery: [:])
    }

    private func getValue(key: String, extraQuery: [String: Any]) throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        for (queryKey, value) in extraQuery {
            query[queryKey] = value
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return value
    }

    private func listAccounts(extraQuery: [String: Any]) throws -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        for (queryKey, value) in extraQuery {
            query[queryKey] = value
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return []
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        let rawItems: [[String: Any]]
        if let array = result as? [[String: Any]] {
            rawItems = array
        } else if let single = result as? [String: Any] {
            rawItems = [single]
        } else {
            throw KeychainError.invalidData
        }

        let accounts = try rawItems.map { item -> String in
            guard let account = item[kSecAttrAccount as String] as? String else {
                throw KeychainError.invalidData
            }
            return account
        }

        return Array(Set(accounts)).sorted()
    }

    private func deleteSynchronizableIfExists(key: String) throws -> Bool {
        return try deleteValue(
            key: key,
            extraQuery: [kSecAttrSynchronizable as String: kCFBooleanTrue!]
        )
    }

    private func deleteLocalIfExists(key: String) throws -> Bool {
        return try deleteValue(key: key, extraQuery: [:])
    }

    private func deleteValue(key: String, extraQuery: [String: Any]) throws -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        for (queryKey, value) in extraQuery {
            query[queryKey] = value
        }

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound {
            return false
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        return true
    }

    private func isSyncUnavailable(status: OSStatus) -> Bool {
        status == errSecMissingEntitlement || status == -34018
    }
}
