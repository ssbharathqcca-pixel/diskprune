import Combine
import XCTest
@testable import DiskPrune

@MainActor
final class UIPipelineTests: XCTestCase {
    func testSafeItemsPreselectedReviewNotProtectedUnselectable() throws {
        let knowledge = try StorageKnowledge.load()
        let session = AppSession(knowledge: knowledge)
        let root = URL(fileURLWithPath: "/Users/tester/Library/Caches/demo")
        let safe = TestSupport.makeItem(url: root.appendingPathComponent("safe"), fileID: FileID(dev: 1, ino: 1), displayName: "safe", safety: .safe)
        let review = TestSupport.makeItem(url: root.appendingPathComponent("review"), fileID: FileID(dev: 1, ino: 2), displayName: "review", safety: .review)
        let protected = TestSupport.makeItem(url: root.appendingPathComponent("prot"), fileID: FileID(dev: 1, ino: 3), displayName: "prot", safety: .protected, knowledgeID: "user-documents")
        let advanced = TestSupport.makeItem(url: root.appendingPathComponent("adv"), fileID: FileID(dev: 1, ino: 4), displayName: "adv", safety: .advanced, knowledgeID: "docker-raw")
        let coverage = StorageCoverage(
            volumeTotalBytes: 1000,
            volumeAvailableBytes: 400,
            classifiedBytes: 400,
            unclassifiedScannedBytes: 0,
            permissionLimitedPaths: [],
            cleanupCandidateBytes: 200
        )
        session.ingestScan(items: [safe, review, protected, advanced], coverage: coverage)
        XCTAssertTrue(session.isSelected(safe))
        XCTAssertFalse(session.isSelected(review))
        XCTAssertFalse(session.canSelect(protected))
        XCTAssertFalse(session.canSelect(advanced))
        session.setSelected(protected, true)
        session.setSelected(advanced, true)
        XCTAssertFalse(session.isSelected(protected))
        XCTAssertFalse(session.isSelected(advanced))
        session.setSelected(review, true)
        XCTAssertTrue(session.isSelected(review))
        XCTAssertNotNil(session.currentPlan)
    }

    func testPlanUsesPlannedItemAndCleanupPlanOnly() throws {
        let knowledge = try StorageKnowledge.load()
        let session = AppSession(knowledge: knowledge)
        let url = URL(fileURLWithPath: "/Users/tester/Library/Caches/demo/item")
        let item = TestSupport.makeItem(url: url, fileID: FileID(dev: 1, ino: 11), onDiskBytes: 4096, safety: .safe)
        let coverage = StorageCoverage(
            volumeTotalBytes: 1000,
            volumeAvailableBytes: 400,
            classifiedBytes: 4096,
            unclassifiedScannedBytes: 0,
            permissionLimitedPaths: [],
            cleanupCandidateBytes: 4096
        )
        session.ingestScan(items: [item], coverage: coverage)
        let planned = PlannedItem(item: item, userSelected: true)
        XCTAssertNotNil(planned)
        XCTAssertNotNil(session.currentPlan)
        XCTAssertEqual(session.currentPlan?.itemCount, 1)
        XCTAssertEqual(session.estimatedRecoverable, session.currentPlan?.estimatedRecoverableBytes)
    }

    func testUISourcesDoNotCallLegacyTrashOrLicenseGate() throws {
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DiskPrune/UI")
        let enumerator = FileManager.default.enumerator(at: ui, includingPropertiesForKeys: nil)
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" { files.append(url) }
        }
        XCTAssertFalse(files.isEmpty, "UI sources missing")
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(text.contains("ScannerActor"), "\(url.lastPathComponent) references ScannerActor")
            XCTAssertFalse(text.contains("trash(urls:"), "\(url.lastPathComponent) calls trash(urls:)")
            XCTAssertFalse(text.contains("SafetyRules"), "\(url.lastPathComponent) references SafetyRules")
            XCTAssertFalse(text.contains("LicenseManager"), "\(url.lastPathComponent) gates on LicenseManager")
            let snapshotDelete = "delete" + "localsnapshots"
            XCTAssertFalse(text.contains(snapshotDelete), "\(url.lastPathComponent) exposes snapshot deletion")
            XCTAssertFalse(text.contains("removeItem"), "\(url.lastPathComponent) uses removeItem")
        }
    }

    func testSidebarSelectionWritebackDoesNotPublishNoOp() throws {
        let knowledge = try StorageKnowledge.load()
        let session = AppSession(knowledge: knowledge)
        var fires = 0
        let hook = session.objectWillChange.sink { fires += 1 }
        _ = hook
        let baseline = fires
        session.destination = .overview
        session.sidebarSelection.wrappedValue = .overview
        XCTAssertEqual(fires, baseline, "same destination must not publish")
        XCTAssertEqual(session.destination, .overview)
        session.destination = .cleanup
        XCTAssertEqual(fires, baseline + 1)
        session.sidebarSelection.wrappedValue = .cleanup
        XCTAssertEqual(fires, baseline + 1)
        session.sidebarSelection.wrappedValue = .category(.developer)
        XCTAssertEqual(fires, baseline + 2)
        XCTAssertEqual(session.destination, .category(.developer))
    }

    func testIngestScanDoesNotChangeDestination() throws {
        let knowledge = try StorageKnowledge.load()
        let session = AppSession(knowledge: knowledge)
        XCTAssertEqual(session.destination, .overview)
        let item = TestSupport.makeItem(
            url: URL(fileURLWithPath: "/Users/tester/Library/Caches/demo/item"),
            fileID: FileID(dev: 1, ino: 21),
            onDiskBytes: 4096,
            safety: .safe
        )
        let coverage = StorageCoverage(
            volumeTotalBytes: 1000,
            volumeAvailableBytes: 400,
            classifiedBytes: 4096,
            unclassifiedScannedBytes: 0,
            permissionLimitedPaths: [],
            cleanupCandidateBytes: 4096
        )
        session.ingestScan(items: [item], coverage: coverage)
        XCTAssertEqual(session.destination, .overview)
        XCTAssertEqual(session.phase, .ready)
        XCTAssertNotNil(session.coverage)
    }
}
