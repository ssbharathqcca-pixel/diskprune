import Foundation
import Security

/// Typed Keychain wrapper. Presence of an item is never an entitlement.
struct KeychainStore {
    enum Account: String {
        case deviceId = "device-id"
        case token = "license-token"
        case verifiedToken = "license-token-verified"
        case licenseKey = "license-key"
        case lastOnline = "last-online-verification"
        case maxSeenTime = "max-seen-time"
        case requiresOnlineCheckBy = "requires-online-check-by"
        case pendingEndReason = "pending-end-reason"
    }

    final class Memory {
        var items: [String: Data] = [:]
    }

    static let standard = KeychainStore(service: "com.diskprune.app")

    let service: String
    private let memory: Memory?

    init(service: String = "com.diskprune.app", memory: Memory? = nil) {
        self.service = service
        self.memory = memory
    }

    static func memory() -> KeychainStore {
        KeychainStore(service: "com.diskprune.app.memory", memory: Memory())
    }

    func data(for account: Account) -> Data? {
        data(forAccount: account.rawValue)
    }

    func string(_ account: Account) -> String? {
        guard let data = data(for: account), let value = String(data: data, encoding: .utf8), !value.isEmpty else {
            return nil
        }
        return value
    }

    func date(_ account: Account) -> Date? {
        guard let raw = string(account), let interval = TimeInterval(raw) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    func set(_ account: Account, data: Data) {
        set(account: account.rawValue, data: data)
    }

    func set(_ account: Account, string: String) {
        set(account, data: Data(string.utf8))
    }

    func set(_ account: Account, date: Date) {
        set(account, string: String(date.timeIntervalSince1970))
    }

    func remove(_ account: Account) {
        remove(account: account.rawValue)
    }

    func data(forAccount account: String) -> Data? {
        if let memory {
            return memory.items[account]
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    func set(account: String, data: Data) {
        if let memory {
            memory.items[account] = data
            return
        }
        remove(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func remove(account: String) {
        if let memory {
            memory.items.removeValue(forKey: account)
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
