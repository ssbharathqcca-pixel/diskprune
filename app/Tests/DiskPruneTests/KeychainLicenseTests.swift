import XCTest
@testable import DiskPrune

@MainActor
final class KeychainLicenseTests: XCTestCase {
    func testKC01_genericPasswordDoesNotEnableCleanup() {
        let store = KeychainStore.memory()
        store.set(account: "DiskPruneLicense", data: Data("I-am-not-a-token".utf8))
        store.set(.token, string: "not-a-compact-dpl")
        let manager = LicenseManager(store: store, api: MockLicenseAPI(), keys: [:])
        XCTAssertFalse(manager.canClean)
        XCTAssertTrue(manager.entitlements.isEmpty)
        XCTAssertEqual(manager.status, .notActivated)
    }

    func testKC02_deletingDeviceIdIssuesNewUUID() {
        let store = KeychainStore.memory()
        let first = DeviceIdentity.current(store: store)
        XCTAssertFalse(first.isEmpty)
        store.remove(.deviceId)
        let second = DeviceIdentity.current(store: store)
        XCTAssertNotEqual(first, second)
    }

    func testDEV01_freshInstallCreatesDeviceRow() {
        let store = KeychainStore.memory()
        XCTAssertNil(store.string(.deviceId))
        let id = DeviceIdentity.current(store: store)
        XCTAssertEqual(store.string(.deviceId), id)
        XCTAssertEqual(id.count, 36)
    }

    func testDEV02_secondLaunchReusesUUID() {
        let store = KeychainStore.memory()
        let first = DeviceIdentity.current(store: store)
        let second = DeviceIdentity.current(store: store)
        XCTAssertEqual(first, second)
    }

    func testB11_isActivatedPresenceAPIRemoved() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DiskPrune")
        let manager = try String(contentsOf: root.appendingPathComponent("Licensing/LicenseManager.swift"), encoding: .utf8)
        XCTAssertFalse(manager.contains("isActivated"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("LicenseManager.swift").path))
        let identity = try String(contentsOf: root.appendingPathComponent("Licensing/DeviceIdentity.swift"), encoding: .utf8)
        XCTAssertFalse(identity.contains("IOPlatformSerialNumber"))
        XCTAssertFalse(identity.contains("kIOPlatformUUIDKey"))
        XCTAssertFalse(identity.contains("IOPlatformUUID"))
        let pub = try String(contentsOf: root.appendingPathComponent("Licensing/PublicKeys.swift"), encoding: .utf8)
        XCTAssertFalse(pub.contains("MC4CAQAwBQYDK2Vw"), "PKCS#8 Ed25519 private key must not be in PublicKeys.swift")
        XCTAssertFalse(pub.contains("BEGIN PRIVATE"))
        XCTAssertTrue(pub.contains("PublicKey"))
        XCTAssertTrue(pub.contains("k1Base64"))
    }

    func testKeychainUsesServiceAndThisDeviceOnly() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/DiskPrune/Licensing/KeychainStore.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(text.contains("com.diskprune.app"))
        XCTAssertTrue(text.contains("kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly"))
        XCTAssertTrue(text.contains("kSecAttrService"))
    }
}
