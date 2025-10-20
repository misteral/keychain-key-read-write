import Foundation
import Security

enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case invalidData

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
        }
    }
}

class KeychainManager {
    private let service: String

    init(service: String = "kc-cli") {
        self.service = service
    }

    // Set or update a key in the keychain
    func set(key: String, value: String) throws {
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Try to add with synchronizable first, fall back to local-only if it fails
        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: valueData,
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]

        var addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        // If synchronizable failed with -34018, try without synchronizable
        if addStatus == errSecMissingEntitlement || addStatus == -34018 {
            addQuery.removeValue(forKey: kSecAttrSynchronizable as String)
            addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        }

        // If item already exists, update it instead
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

            if updateStatus != errSecSuccess {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        } else if addStatus != errSecSuccess {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    // Get a key from the keychain
    func get(key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return value
    }

    // Delete a key from the keychain
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }

        if status == errSecItemNotFound {
            throw KeychainError.itemNotFound
        }
    }
}
