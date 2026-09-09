import XCTest
@testable import DiskPrune

@MainActor
final class OfflineLicenseTests: XCTestCase {
    func testOFF01_validTokenOfflineStillAllowsCleanup() {
        let (manager, _, _, _, _) = LicenseFixtures.manager()
        XCTAssertTrue(manager.canClean)
        XCTAssertEqual(manager.status, .active)
    }

    func testOFF02_expiredTokenDisablesCleanupButScanWorks() throws {
        let (manager, _, _, _, _) = LicenseFixtures.manager(expired: true)
        XCTAssertFalse(manager.canClean)
        XCTAssertEqual(manager.status, .expired)
        XCTAssertFalse(manager.cleanupBlockedMessage.lowercased().contains("invalid"))
        try assertScanWorks(with: manager)
    }

    func testOFF03_clockRollbackFailsOpen() {
        let (manager, clock, store, _, _) = LicenseFixtures.manager()
        XCTAssertTrue(manager.canClean)
        clock.date = LicenseFixtures.t0.addingTimeInterval(-30 * LicenseFixtures.day)
        manager.evaluate()
        XCTAssertTrue(manager.canClean, "clock rollback must fail open")
        XCTAssertEqual(manager.clockWarning, "Your Mac's clock appears to be incorrect")
        XCTAssertNotNil(store.date(.requiresOnlineCheckBy))
    }

    func testOFF04_deadlinePassedStillOfflineDisablesCleanup() throws {
        let (manager, clock, _, _, _) = LicenseFixtures.manager()
        clock.date = LicenseFixtures.t0.addingTimeInterval(-30 * LicenseFixtures.day)
        manager.evaluate()
        clock.date = LicenseFixtures.t0.addingTimeInterval(8 * LicenseFixtures.day)
        manager.evaluate()
        XCTAssertFalse(manager.canClean)
        XCTAssertEqual(manager.status, .needsOnlineCheck)
        try assertScanWorks(with: manager)
    }

    func testOFF05_refreshAfterExpiryDoesNotNeedKeyReentry() async {
        let api = MockLicenseAPI()
        api.error = nil
        let pair = TestTokens.pair()
        let (manager, _, store, _, _) = LicenseFixtures.manager(expired: true, pair: pair, api: api)
        XCTAssertFalse(manager.canClean)
        let fresh = TestTokens.issue(
            privateKey: pair.privateKey,
            deviceId: manager.deviceId,
            now: LicenseFixtures.t0,
            ttl: 90 * LicenseFixtures.day
        )
        api.refreshStatus = 200
        api.refreshJSON = ["token": fresh, "expires_at": Int(LicenseFixtures.t0.timeIntervalSince1970) + Int(90 * LicenseFixtures.day)]
        await manager.refresh()
        XCTAssertTrue(manager.canClean)
        XCTAssertEqual(store.string(.token), fresh)
        XCTAssertEqual(api.refreshBodies.count, 1)
        XCTAssertNil(api.refreshBodies.first?["license_key"])
    }

    func testOFF07_freeTierNeverConsultsLicenseManager() throws {
        let (manager, _, _, _, _) = LicenseFixtures.manager(tokenTTL: nil)
        XCTAssertFalse(manager.canClean)
        try assertScanWorks(with: manager)

        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DiskPrune")
        let freeTier = [
            "UI/ScanView.swift",
            "UI/StorageAutopsyView.swift",
            "UI/ResultsView.swift",
            "UI/ItemDetailView.swift",
            "UI/ReceiptView.swift",
            "UI/SnapshotView.swift",
            "UI/StateViews.swift",
            "Scanning/ScanEngine.swift"
        ]
        for rel in freeTier {
            let text = try String(contentsOf: ui.appendingPathComponent(rel), encoding: .utf8)
            XCTAssertFalse(text.contains("LicenseManager"), "\(rel) consults LicenseManager")
            XCTAssertFalse(text.contains("canClean"), "\(rel) consults canClean")
        }
    }

    func testReleasedRefreshKeepsTokenUntilExpiry() async throws {
        let api = MockLicenseAPI()
        api.error = nil
        api.refreshStatus = 403
        api.refreshJSON = ["error": "DEVICE_RELEASED"]
        let (manager, clock, _, _, _) = LicenseFixtures.manager(api: api)
        XCTAssertTrue(manager.canClean)
        await manager.refresh()
        XCTAssertTrue(manager.canClean, "existing token remains valid until exp")
        clock.date = LicenseFixtures.t0.addingTimeInterval(91 * LicenseFixtures.day)
        manager.evaluate()
        XCTAssertFalse(manager.canClean)
        XCTAssertEqual(manager.status, .releasedExpired)
        try assertScanWorks(with: manager)
    }

    func testRevokedRefreshKeepsTokenUntilExpiry() async {
        let api = MockLicenseAPI()
        api.error = nil
        api.refreshStatus = 403
        api.refreshJSON = ["error": "LICENSE_REVOKED"]
        let (manager, clock, _, _, _) = LicenseFixtures.manager(api: api)
        await manager.refresh()
        XCTAssertTrue(manager.canClean)
        clock.date = LicenseFixtures.t0.addingTimeInterval(91 * LicenseFixtures.day)
        manager.evaluate()
        XCTAssertFalse(manager.canClean)
        XCTAssertFalse(manager.cleanupBlockedMessage.lowercased().contains("invalid"))
    }

    func testDisputedRefreshAcceptsFourteenDayToken() async {
        let api = MockLicenseAPI()
        api.error = nil
        let pair = TestTokens.pair()
        let (manager, _, _, _, _) = LicenseFixtures.manager(pair: pair, api: api)
        let short = TestTokens.issue(
            privateKey: pair.privateKey,
            deviceId: manager.deviceId,
            now: LicenseFixtures.t0,
            ttl: 14 * LicenseFixtures.day
        )
        api.refreshStatus = 200
        api.refreshJSON = ["token": short]
        await manager.refresh()
        XCTAssertTrue(manager.canClean)
        let verified = LicenseToken.verify(short, deviceId: manager.deviceId, now: LicenseFixtures.t0, keys: pair.keys)
        guard case .success(let claims) = verified else { return XCTFail("14-day token") }
        XCTAssertEqual(claims.exp - claims.iat, Int64(14 * LicenseFixtures.day))
    }

    func testActivateStoresVerifiedTokenNotKeychainPresence() async {
        let api = MockLicenseAPI()
        api.error = nil
        let pair = TestTokens.pair()
        let (manager, _, store, _, _) = LicenseFixtures.manager(tokenTTL: nil, pair: pair, api: api)
        let token = TestTokens.issue(
            privateKey: pair.privateKey,
            deviceId: manager.deviceId,
            now: LicenseFixtures.t0,
            ttl: 90 * LicenseFixtures.day
        )
        api.activateStatus = 200
        api.activateJSON = ["token": token, "max_devices": 3, "entitlements": ["cleanup"]]
        await manager.activate(licenseKey: "prune-00000-00000-00000-00000")
        XCTAssertTrue(manager.canClean)
        XCTAssertEqual(store.string(.licenseKey), "PRUNE-00000-00000-00000-00000")
        XCTAssertEqual(api.activateBodies.first?["device_id"] as? String, manager.deviceId)
        XCTAssertNotNil(api.activateBodies.first?["device_name"])
    }

    func testSeatLimitSurfacesDeviceList() async {
        let api = MockLicenseAPI()
        api.error = nil
        api.activateStatus = 409
        api.activateJSON = [
            "error": "SEAT_LIMIT",
            "devices": [["device_id": "d1", "device_name": "Old Mac", "last_seen": 1_800_000_000]]
        ]
        let (manager, _, _, _, _) = LicenseFixtures.manager(tokenTTL: nil, api: api)
        await manager.activate(licenseKey: "PRUNE-00000-00000-00000-00000")
        XCTAssertFalse(manager.canClean)
        XCTAssertEqual(manager.seatLimitDevices.count, 1)
        XCTAssertEqual(manager.seatLimitDevices.first?.deviceName, "Old Mac")
    }

    func testUnknownKidKeepsPreviouslyVerifiedToken() {
        let pair = TestTokens.pair()
        let store = KeychainStore.memory()
        let device = DeviceIdentity.current(store: store)
        let good = TestTokens.issue(privateKey: pair.privateKey, deviceId: device, now: LicenseFixtures.t0, ttl: 90 * LicenseFixtures.day)
        let k2 = TestTokens.pair(kid: "k2")
        let rotated = TestTokens.issue(privateKey: k2.privateKey, kid: "k2", deviceId: device, now: LicenseFixtures.t0, ttl: 90 * LicenseFixtures.day)
        store.set(.verifiedToken, string: good)
        store.set(.token, string: rotated)
        let manager = LicenseManager(store: store, api: MockLicenseAPI(), clock: { LicenseFixtures.t0 }, keys: pair.keys)
        XCTAssertTrue(manager.canClean)
    }

    func testTamperedStoredTokenIsDeleted() {
        let pair = TestTokens.pair()
        let store = KeychainStore.memory()
        let device = DeviceIdentity.current(store: store)
        let good = TestTokens.issue(privateKey: pair.privateKey, deviceId: device, now: LicenseFixtures.t0, ttl: 90 * LicenseFixtures.day)
        store.set(.token, string: TestTokens.bitFlip(good))
        let manager = LicenseManager(store: store, api: MockLicenseAPI(), clock: { LicenseFixtures.t0 }, keys: pair.keys)
        XCTAssertFalse(manager.canClean)
        XCTAssertNil(store.string(.token))
    }

    func testCleanupBlockedWithoutLicense() throws {
        let (manager, _, _, _, _) = LicenseFixtures.manager(tokenTTL: nil)
        let knowledge = try StorageKnowledge.load()
        let session = AppSession(knowledge: knowledge, license: manager)
        let item = TestSupport.makeItem(
            url: URL(fileURLWithPath: "/Users/tester/Library/Caches/demo/item"),
            fileID: FileID(dev: 1, ino: 31),
            onDiskBytes: 4096,
            safety: .safe
        )
        session.ingestScan(
            items: [item],
            coverage: StorageCoverage(
                volumeTotalBytes: 1000,
                volumeAvailableBytes: 400,
                classifiedBytes: 4096,
                unclassifiedScannedBytes: 0,
                permissionLimitedPaths: [],
                cleanupCandidateBytes: 4096
            )
        )
        XCTAssertNotNil(session.currentPlan)
        session.confirmMoveToTrash()
        XCTAssertNotEqual(session.phase, .executing)
        XCTAssertFalse(session.showReceipt)
    }

    private func assertScanWorks(with manager: LicenseManager) throws {
        let knowledge = try StorageKnowledge.load()
        let session = AppSession(knowledge: knowledge, license: manager)
        let item = TestSupport.makeItem(
            url: URL(fileURLWithPath: "/Users/tester/Library/Caches/demo/item"),
            fileID: FileID(dev: 1, ino: 41),
            onDiskBytes: 4096,
            safety: .safe
        )
        session.ingestScan(
            items: [item],
            coverage: StorageCoverage(
                volumeTotalBytes: 1000,
                volumeAvailableBytes: 400,
                classifiedBytes: 4096,
                unclassifiedScannedBytes: 0,
                permissionLimitedPaths: [],
                cleanupCandidateBytes: 4096
            )
        )
        XCTAssertEqual(session.phase, .ready)
        XCTAssertNotNil(session.coverage)
        XCTAssertEqual(session.items.count, 1)
    }
}
