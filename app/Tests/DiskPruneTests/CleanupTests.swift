import XCTest
@testable import DiskPrune

final class CleanupTests: XCTestCase {
    func testCLN01_oneFailureDoesNotAbortBatch() async throws {
        let root = try TestSupport.uniqueTemp()
        var planned: [PlannedItem] = []
        for i in 0..<10 {
            let dir = root.appendingPathComponent("item-\(i)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try TestSupport.writeRandomFile(at: dir.appendingPathComponent("f.bin"), size: 1024)
            let st = try unwrapStat(dir)
            let item = TestSupport.makeItem(url: dir, fileID: st.fileID, objectType: st.objectType, cleanupRoot: root)
            guard let p = PlannedItem(item: item, userSelected: true) else {
                XCTFail("item \(i) not plannable")
                return
            }
            planned.append(p)
        }
        // Remove item 3 after planning so TOCTOU records vanished; others still trash.
        try FileManager.default.removeItem(at: root.appendingPathComponent("item-3"))
        guard let plan = CleanupPlan(items: planned) else {
            XCTFail("plan")
            return
        }
        let receipt = await CleanupExecutor().execute(plan)
        let trashed = receipt.outcomes.filter {
            if case .trashed = $0 { return true }
            return false
        }
        let skipped = receipt.outcomes.filter {
            if case .skipped(_, _, _, .vanished) = $0 { return true }
            return false
        }
        XCTAssertEqual(trashed.count, 9)
        XCTAssertEqual(skipped.count, 1)
        XCTAssertEqual(receipt.outcomes.count, 10)
    }

    func testCLN05_unplannedSiblingSurvives() async throws {
        let root = try TestSupport.uniqueTemp()
        let target = root.appendingPathComponent("target")
        let sibling = root.appendingPathComponent("sibling")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        try TestSupport.writeRandomFile(at: target.appendingPathComponent("t.bin"), size: 512)
        try TestSupport.writeRandomFile(at: sibling.appendingPathComponent("s.bin"), size: 512)
        let st = try unwrapStat(target)
        let item = TestSupport.makeItem(url: target, fileID: st.fileID, objectType: st.objectType, cleanupRoot: root)
        guard let p = PlannedItem(item: item, userSelected: true), let plan = CleanupPlan(items: [p]) else {
            XCTFail("plan")
            return
        }
        _ = await CleanupExecutor().execute(plan)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sibling.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sibling.appendingPathComponent("s.bin").path))
    }

    func testTOC01_vanished() async throws {
        let root = try TestSupport.uniqueTemp()
        let dir = root.appendingPathComponent("gone")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let st = try unwrapStat(dir)
        let item = TestSupport.makeItem(url: dir, fileID: st.fileID, objectType: st.objectType, cleanupRoot: root)
        guard let p = PlannedItem(item: item, userSelected: true), let plan = CleanupPlan(items: [p]) else {
            XCTFail("plan")
            return
        }
        try FileManager.default.removeItem(at: dir)
        let receipt = await CleanupExecutor().execute(plan)
        guard case .skipped(_, _, _, .vanished) = receipt.outcomes.first else {
            XCTFail("expected vanished, got \(receipt.outcomes)")
            return
        }
    }

    func testTOC02_becameSymlink() async throws {
        let root = try TestSupport.uniqueTemp()
        let dir = root.appendingPathComponent("swap")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let st = try unwrapStat(dir)
        let item = TestSupport.makeItem(url: dir, fileID: st.fileID, objectType: .directory, cleanupRoot: root)
        guard let p = PlannedItem(item: item, userSelected: true), let plan = CleanupPlan(items: [p]) else {
            XCTFail("plan")
            return
        }
        try FileManager.default.removeItem(at: dir)
        try FileManager.default.createSymbolicLink(at: dir, withDestinationURL: root.appendingPathComponent("elsewhere"))
        let receipt = await CleanupExecutor().execute(plan)
        guard case .skipped(_, _, _, let reason) = receipt.outcomes.first else {
            XCTFail("expected skip \(receipt.outcomes)")
            return
        }
        XCTAssertTrue(reason == .becameSymlink || reason == .identityChanged || reason == .typeChanged)
    }

    func testTOC04_identityChanged() async throws {
        let root = try TestSupport.uniqueTemp()
        let dir = root.appendingPathComponent("id")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let st = try unwrapStat(dir)
        let item = TestSupport.makeItem(url: dir, fileID: st.fileID, objectType: st.objectType, cleanupRoot: root)
        guard let p = PlannedItem(item: item, userSelected: true), let plan = CleanupPlan(items: [p]) else {
            XCTFail("plan")
            return
        }
        try FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let receipt = await CleanupExecutor().execute(plan)
        guard case .skipped(_, _, _, .identityChanged) = receipt.outcomes.first else {
            XCTFail("expected identityChanged \(receipt.outcomes)")
            return
        }
    }

    func testRCP01_roundTrip() throws {
        let receipt = CleanupReceipt(
            id: UUID(),
            planID: UUID(),
            startedAt: Date(),
            finishedAt: Date(),
            wasCancelled: false,
            estimatedRecoverableBytes: 10,
            successfullyTrashedBytes: 10,
            volumeAvailableBefore: 100,
            volumeAvailableAfter: 100,
            immediateAvailableDelta: 0,
            outcomes: [],
            trashLocation: "/tmp",
            appVersion: "0.0.0-dev",
            rulesVersion: "2026.09.1"
        )
        let url = try ReceiptStore.save(receipt)
        let loaded = try ReceiptStore.load(url)
        XCTAssertEqual(loaded.id, receipt.id)
        XCTAssertEqual(loaded.successfullyTrashedBytes, 10)
    }

    func testCOV03_permissionLimitedBytesNil() {
        let coverage = StorageCoverage(
            volumeTotalBytes: 1000,
            volumeAvailableBytes: 400,
            classifiedBytes: 100,
            unclassifiedScannedBytes: 50,
            permissionLimitedPaths: ["/secret"],
            cleanupCandidateBytes: 40
        )
        XCTAssertNil(coverage.permissionLimitedBytes)
        XCTAssertEqual(coverage.examinedBytes, 150)
        XCTAssertEqual(coverage.notExaminedBytes, 450)
    }

    func testCOV04_clampsNotExamined() {
        let coverage = StorageCoverage(
            volumeTotalBytes: 100,
            volumeAvailableBytes: 90,
            classifiedBytes: 50,
            unclassifiedScannedBytes: 50,
            permissionLimitedPaths: [],
            cleanupCandidateBytes: 0
        )
        XCTAssertEqual(coverage.notExaminedBytes, 0)
    }

    private func unwrapStat(_ url: URL) throws -> FileIdentity.Stat {
        switch FileIdentity.lstat(url.path) {
        case .success(let st): return st
        case .failure(let err): throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(err)"])
        }
    }
}
