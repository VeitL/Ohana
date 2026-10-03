//
//  GuardianDeviceIdentityStore.swift
//  Ohana
//
//  Per-installation pseudonymous identifier used only to revoke the current
//  APNs endpoint. ThisDeviceOnly Keychain storage keeps it out of backups.
//

import Foundation
import Security

final nonisolated class GuardianDeviceIdentityStore: @unchecked Sendable {
    static let shared = GuardianDeviceIdentityStore()

    private let service = "com.guanchen.li.Ohana.guardian-device"
    private let account = "installation.v1"
    private let lock = NSLock()

    func identifier() -> String {
        lock.withLock {
            if let existing = load(), UUID(uuidString: existing) != nil {
                return existing
            }
            let value = UUID().uuidString.lowercased()
            save(value)
            return value
        }
    }

    func clear() {
        _ = lock.withLock {
            SecItemDelete(baseQuery as CFDictionary)
        }
    }

    private func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func save(_ value: String) {
        let data = Data(value.utf8)
        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemDelete(baseQuery as CFDictionary)
        SecItemAdd(item as CFDictionary, nil)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
