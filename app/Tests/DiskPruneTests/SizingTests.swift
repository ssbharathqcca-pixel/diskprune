import Darwin
import XCTest
@testable import DiskPrune

final class SizingTests: XCTestCase {
    func testSIZE01_threeFiles() async throws {
        let root = try TestSupport.uniqueTemp()
        try TestSupport.writeRandomFile(at: root.appendingPathComponent("a.bin"), size: 1_048_576)
        try TestSupport.writeRandomFile(at: root.appendingPathComponent("b.bin"), size: 2_097_152)
        try TestSupport.writeRandomFile(at: root.appendingPathComponent("c.bin"), size: 4_194_304)
        let result = await DirectorySizer.measure(root: root, globalSeen: SeenFileIDs())
        let expected: Int64 = 1_048_576 + 2_097_152 + 4_194_304
        XCTAssertEqual(result.fileCount, 3)
        XCTAssertLessThanOrEqual(abs(result.onDiskBytes - expected), 512 * 8)
    }

    func testSIZE02_depthCap() async throws {
        var url = try TestSupport.uniqueTemp()
        for i in 0..<70 {
            url = url.appendingPathComponent("d\(i)")
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try TestSupport.writeRandomFile(at: url.appendingPathComponent("leaf.bin"), size: 1024)
        let root = url.deletingLastPathComponent()
        // measure from the temp root 70 levels up
        var walk = url
        for _ in 0..<70 { walk = walk.deletingLastPathComponent() }
        let result = await DirectorySizer.measure(root: walk, globalSeen: SeenFileIDs())
        XCTAssertEqual(result.scanState, .complete)
        _ = root
    }

    func testSIZE05_emptyDirectory() async throws {
        let root = try TestSupport.uniqueTemp()
        let result = await DirectorySizer.measure(root: root, globalSeen: SeenFileIDs())
        XCTAssertEqual(result.fileCount, 0)
        XCTAssertEqual(result.scanState, .complete)
    }

    func testSIZE06_appBundleNoChildSemantics() async throws {
        let root = try TestSupport.uniqueTemp()
        let app = root.appendingPathComponent("Demo.app")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try TestSupport.writeRandomFile(at: app.appendingPathComponent("Contents/MacOS/Demo"), size: 4096)
        let result = await DirectorySizer.measure(root: root, globalSeen: SeenFileIDs())
        XCTAssertGreaterThan(result.onDiskBytes, 0)
    }

    func testSPARSE01_allocatedMuchLessThanLogical() async throws {
        let root = try TestSupport.uniqueTemp()
        let file = root.appendingPathComponent("sparse.dat")
        let path = file.path
        let fd = open(path, O_RDWR | O_CREAT, 0o644)
        XCTAssertGreaterThanOrEqual(fd, 0)
        let tenGB = off_t(10) * 1024 * 1024 * 1024
        XCTAssertEqual(ftruncate(fd, tenGB), 0)
        close(fd)
        let result = await DirectorySizer.measure(root: file, globalSeen: SeenFileIDs())
        XCTAssertEqual(result.logicalBytes, Int64(tenGB))
        XCTAssertLessThan(result.onDiskBytes, result.logicalBytes / 2)
    }

    func testSYM01_doesNotFollow() async throws {
        let root = try TestSupport.uniqueTemp()
        let target = root.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try TestSupport.writeRandomFile(at: target.appendingPathComponent("big.bin"), size: 1_048_576)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let result = await DirectorySizer.measure(root: link, globalSeen: SeenFileIDs())
        XCTAssertLessThan(result.onDiskBytes, 100_000)
        XCTAssertEqual(result.fileCount, 0)
    }

    func testHL01_hardlinkCountedOnce() async throws {
        let root = try TestSupport.uniqueTemp()
        let a = root.appendingPathComponent("a.bin")
        try TestSupport.writeRandomFile(at: a, size: 1_048_576)
        let b = root.appendingPathComponent("b.bin")
        XCTAssertEqual(link(a.path, b.path), 0)
        let result = await DirectorySizer.measure(root: root, globalSeen: SeenFileIDs())
        XCTAssertLessThanOrEqual(abs(result.onDiskBytes - 1_048_576), 512 * 4)
        XCTAssertFalse(result.encounteredFileIDs.isEmpty)
    }
}
