import Foundation

/// Random UUID persisted in Keychain. No hardware identifiers.
enum DeviceIdentity {
    static func current(store: KeychainStore = .standard) -> String {
        if let existing = store.string(.deviceId) {
            return existing
        }
        let id = UUID().uuidString
        store.set(.deviceId, string: id)
        return id
    }
}
