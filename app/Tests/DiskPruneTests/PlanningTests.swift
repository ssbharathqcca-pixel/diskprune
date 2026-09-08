import XCTest
@testable import DiskPrune

final class PlanningTests: XCTestCase {
    private func deepTemp() throws -> URL {
        let root = try TestSupport.uniqueTemp()
        let url = root.appendingPathComponent("cache").appendingPathComponent("item")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testPLAN01_requiresUserSelection() throws {
        let url = try deepTemp()
        let item = TestSupport.makeItem(url: url, cleanupRoot: url.deletingLastPathComponent())
        XCTAssertNil(PlannedItem(item: item, userSelected: false))
    }

    func testPLAN02_rejectsProtected() throws {
        let url = try deepTemp()
        let item = TestSupport.makeItem(
            url: url,
            safety: .protected,
            knowledgeID: "protected-documents",
            cleanupRoot: url.deletingLastPathComponent()
        )
        XCTAssertNil(PlannedItem(item: item, userSelected: true))
    }

    func testPLAN02b_rejectsAdvanced() throws {
        let url = try deepTemp()
        let item = TestSupport.makeItem(
            url: url,
            safety: .advanced,
            knowledgeID: "docker-raw",
            cleanupRoot: url.deletingLastPathComponent()
        )
        XCTAssertNil(PlannedItem(item: item, userSelected: true))
    }

    func testPLAN03_requiresKnowledgeID() throws {
        let url = try deepTemp()
        let item = TestSupport.makeItem(
            url: url,
            knowledgeID: nil,
            cleanupRoot: url.deletingLastPathComponent()
        )
        XCTAssertFalse(item.isCleanupCandidate)
        XCTAssertNil(PlannedItem(item: item, userSelected: true))
    }

    func testPLAN04_rejectsSymlink() throws {
        let url = try deepTemp()
        let item = TestSupport.makeItem(
            url: url,
            objectType: .symlink,
            cleanupRoot: url.deletingLastPathComponent()
        )
        XCTAssertNil(PlannedItem(item: item, userSelected: true))
    }

    func testPLAN05_rejectsAppAncestor() throws {
        let root = try TestSupport.uniqueTemp()
        let app = root.appendingPathComponent("Foo.app").appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let item = TestSupport.makeItem(url: app, cleanupRoot: root)
        XCTAssertNil(PlannedItem(item: item, userSelected: true))
    }

    func testPLAN06_rejectsEscapeFromCleanupRoot() throws {
        let a = try TestSupport.uniqueTemp()
        let b = try TestSupport.uniqueTemp()
        let url = a.appendingPathComponent("cache").appendingPathComponent("item")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let item = TestSupport.makeItem(url: url, cleanupRoot: b)
        XCTAssertNil(PlannedItem(item: item, userSelected: true))
    }

    func testPLAN07_rejectsDenyList() throws {
        let docs = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        let item = TestSupport.makeItem(url: docs, cleanupRoot: docs.deletingLastPathComponent())
        XCTAssertNil(PlannedItem(item: item, userSelected: true))
    }

    func testPLAN08_rejectsShallowPaths() throws {
        let item = TestSupport.makeItem(
            url: URL(fileURLWithPath: "/tmp"),
            cleanupRoot: URL(fileURLWithPath: "/")
        )
        XCTAssertNil(PlannedItem(item: item, userSelected: true))
    }

    func testPLAN09_emptyPlanNil() {
        XCTAssertNil(CleanupPlan(items: []))
    }

    func testPLAN10_ancestorDescendantNil() throws {
        let root = try TestSupport.uniqueTemp()
        let parent = root.appendingPathComponent("cache")
        let child = parent.appendingPathComponent("item")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        let p = TestSupport.makeItem(url: parent, fileID: FileID(dev: 1, ino: 1), cleanupRoot: root)
        let c = TestSupport.makeItem(url: child, fileID: FileID(dev: 1, ino: 2), cleanupRoot: root)
        guard let pp = PlannedItem(item: p, userSelected: true),
              let cp = PlannedItem(item: c, userSelected: true)
        else {
            XCTFail("expected both items to be plannable")
            return
        }
        XCTAssertNil(CleanupPlan(items: [pp, cp]))
    }

    func testValidPlan() throws {
        let root = try TestSupport.uniqueTemp()
        let a = root.appendingPathComponent("cache-a")
        let b = root.appendingPathComponent("cache-b")
        try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
        let ia = TestSupport.makeItem(url: a, fileID: FileID(dev: 1, ino: 10), cleanupRoot: root)
        let ib = TestSupport.makeItem(url: b, fileID: FileID(dev: 1, ino: 11), cleanupRoot: root)
        guard let pa = PlannedItem(item: ia, userSelected: true),
              let pb = PlannedItem(item: ib, userSelected: true)
        else {
            XCTFail("expected plannable")
            return
        }
        XCTAssertNotNil(CleanupPlan(items: [pa, pb]))
    }
}
