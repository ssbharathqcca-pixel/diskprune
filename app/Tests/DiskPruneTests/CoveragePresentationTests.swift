import XCTest
@testable import DiskPrune

final class CoveragePresentationTests: XCTestCase {
    func testCOV02_headlineNeverImpliesClassifiedEqualsUsed() {
        let coverage = StorageCoverage(
            volumeTotalBytes: 512_000_000_000,
            volumeAvailableBytes: 94_000_000_000,
            classifiedBytes: 82_100_000_000,
            unclassifiedScannedBytes: 12_100_000_000,
            permissionLimitedPaths: [],
            cleanupCandidateBytes: 38_400_000_000
        )
        let model = AutopsyModel(coverage: coverage, items: [], volumeName: "Macintosh HD", cancelled: false)
        XCTAssertNotEqual(model.classifiedBytes, model.volumeUsedBytes)
        XCTAssertEqual(model.examinedBytes, coverage.examinedBytes)
        XCTAssertEqual(model.notExaminedBytes, coverage.notExaminedBytes)
        XCTAssertGreaterThan(model.notExaminedBytes, 0)
        XCTAssertFalse(model.statement.lowercased().contains("whole disk"))
        XCTAssertEqual(model.classifiedBytes, coverage.classifiedBytes)
    }

    func testHL04_headlineUsesCoverageNotItemSum() {
        let a = TestSupport.makeItem(
            url: URL(fileURLWithPath: "/tmp/diskprune-tests/a"),
            fileID: FileID(dev: 1, ino: 9),
            onDiskBytes: 80
        )
        let b = TestSupport.makeItem(
            url: URL(fileURLWithPath: "/tmp/diskprune-tests/b"),
            fileID: FileID(dev: 1, ino: 9),
            displayName: "b",
            onDiskBytes: 80
        )
        let coverage = StorageCoverage(
            volumeTotalBytes: 1000,
            volumeAvailableBytes: 400,
            classifiedBytes: 80,
            unclassifiedScannedBytes: 0,
            permissionLimitedPaths: [],
            cleanupCandidateBytes: 80
        )
        let model = AutopsyModel(coverage: coverage, items: [a, b], volumeName: "Disk", cancelled: false)
        let itemSum = a.onDiskBytes + b.onDiskBytes
        XCTAssertEqual(model.classifiedBytes, 80)
        XCTAssertNotEqual(model.classifiedBytes, itemSum)
        XCTAssertEqual(model.classifiedBytes, coverage.classifiedBytes)
    }

    func testPermissionLimitedBytesNeverDrawn() {
        let coverage = StorageCoverage(
            volumeTotalBytes: 100,
            volumeAvailableBytes: 40,
            classifiedBytes: 10,
            unclassifiedScannedBytes: 5,
            permissionLimitedPaths: ["/secret"],
            cleanupCandidateBytes: 4
        )
        XCTAssertNil(coverage.permissionLimitedBytes)
        let model = AutopsyModel(coverage: coverage, items: [], volumeName: "Disk", cancelled: false)
        XCTAssertEqual(model.permissionPathCount, 1)
        XCTAssertTrue(model.isPartial)
    }

    func testHatchPathIsFiniteForBarAndLegend() {
        let bar = HatchLines().path(in: CGRect(x: 0, y: 0, width: 620, height: 12))
        XCTAssertFalse(bar.isEmpty)
        XCTAssertTrue(bar.boundingRect.width.isFinite)
        XCTAssertTrue(bar.boundingRect.height.isFinite)
        let legend = HatchLines().path(in: CGRect(x: 0, y: 0, width: 12, height: 8))
        XCTAssertFalse(legend.isEmpty)
        XCTAssertTrue(legend.boundingRect.width.isFinite)
        let empty = HatchLines().path(in: .zero)
        XCTAssertTrue(empty.isEmpty)
        let inf = HatchLines().path(in: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 12))
        XCTAssertTrue(inf.isEmpty)
    }

    func testAutopsyModelDoesNotOverflowWithRealisticGigabyteCounts() {
        let xcodeDerived = TestSupport.makeItem(
            url: URL(fileURLWithPath: "/Users/tester/Library/Developer/Xcode/DerivedData/Demo"),
            fileID: FileID(dev: 1, ino: 11),
            onDiskBytes: 38_400_000_000,
            category: .developerBuild,
            knowledgeID: "xcode-deriveddata"
        )
        let userCaches = TestSupport.makeItem(
            url: URL(fileURLWithPath: "/Users/tester/Library/Caches/user"),
            fileID: FileID(dev: 1, ino: 12),
            onDiskBytes: 6_200_000_000,
            category: .applicationCache,
            knowledgeID: "user-caches"
        )
        let coverage = StorageCoverage(
            volumeTotalBytes: 500_000_000_000,
            volumeAvailableBytes: 80_000_000_000,
            classifiedBytes: 80_000_000_000,
            unclassifiedScannedBytes: 0,
            permissionLimitedPaths: [],
            cleanupCandidateBytes: 12_400_000_000
        )
        let model = AutopsyModel(
            coverage: coverage,
            items: [xcodeDerived, userCaches],
            volumeName: "Macintosh HD",
            cancelled: false
        )
        XCTAssertEqual(model.categoryShares.count, 2)
        let developerShare = model.categoryShares.first(where: { $0.bucket == .developer })
        let cachesShare = model.categoryShares.first(where: { $0.bucket == .caches })
        XCTAssertNotNil(developerShare)
        XCTAssertNotNil(cachesShare)
        XCTAssertGreaterThan(developerShare?.bytes ?? 0, 0)
        XCTAssertGreaterThan(cachesShare?.bytes ?? 0, 0)
        XCTAssertEqual(model.classifiedBytes, 80_000_000_000)
    }
}
