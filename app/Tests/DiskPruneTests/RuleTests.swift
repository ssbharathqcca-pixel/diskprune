import XCTest
@testable import DiskPrune

final class RuleTests: XCTestCase {
    func testLoadSharedRules() throws {
        let knowledge = try loadKnowledge()
        XCTAssertFalse(knowledge.publishedRuleIDs.isEmpty)
        XCTAssertLessThanOrEqual(knowledge.publishedRuleIDs.count, 12)
        XCTAssertEqual(knowledge.rulesVersion, "2026.09.1")
    }

    func testDefaultDenyNeverSafe() throws {
        let knowledge = try loadKnowledge()
        let (safety, category, rule) = knowledge.classify(path: "/tmp/diskprune-no-such-rule-\(UUID().uuidString)")
        XCTAssertEqual(safety, .review)
        XCTAssertEqual(category, .unknown)
        XCTAssertNil(rule)
    }

    func testDerivedDataClassifiedSafe() throws {
        let knowledge = try loadKnowledge()
        let path = NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData/Foo-abc"
        let (safety, category, rule) = knowledge.classify(path: path)
        XCTAssertEqual(safety, .safe)
        XCTAssertEqual(category, .developerBuild)
        XCTAssertEqual(rule?.id, "xcode-deriveddata")
    }

    func testProtectedDocumentsWins() throws {
        let knowledge = try loadKnowledge()
        let path = NSHomeDirectory() + "/Documents/secret.txt"
        let (safety, _, rule) = knowledge.classify(path: path)
        XCTAssertEqual(safety, .protected)
        XCTAssertEqual(rule?.id, "protected-documents")
    }

    func testLongestPrefixWins() throws {
        let knowledge = try loadKnowledge()
        let path = NSHomeDirectory() + "/Library/Caches/Homebrew/downloads"
        let (_, _, rule) = knowledge.classify(path: path)
        XCTAssertEqual(rule?.id, "homebrew-cache")
    }

    func testProtectedRulesAreNotPublished() throws {
        let knowledge = try loadKnowledge()
        for rule in knowledge.allRules where rule.safety == .protected {
            XCTAssertFalse(rule.publish, rule.id)
        }
    }

    func testSnapshotParse() {
        let sample = """
        Snapshots for volume group containing disk /:
        com.apple.TimeMachine.2026-09-01-120000.local
        com.apple.TimeMachine.2026-09-02-081500
        garbage line
        """
        let dates = SnapshotInspector.parse(sample)
        XCTAssertEqual(dates.count, 2)
    }

    func testSafetyHelpers() {
        XCTAssertTrue(SafetyLevel.safe.isPreselectable)
        XCTAssertTrue(SafetyLevel.safe.isPlannable)
        XCTAssertTrue(SafetyLevel.review.isPlannable)
        XCTAssertFalse(SafetyLevel.advanced.isPlannable)
        XCTAssertFalse(SafetyLevel.protected.isPlannable)
        XCTAssertFalse(SafetyLevel.advanced.isPreselectable)
    }

    private func loadKnowledge() throws -> StorageKnowledge {
        let candidates = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("shared/storage-rules.json"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("shared/storage-rules.json"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("../shared/storage-rules.json"),
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return try StorageKnowledge.load(from: Data(contentsOf: url))
        }
        return try StorageKnowledge.load()
    }
}
