import XCTest
@testable import DiskPrune

final class SmokeTests: XCTestCase {
    func testModuleLoads() throws {
        let knowledge = try StorageKnowledge.load()
        XCTAssertFalse(knowledge.publishedRuleIDs.isEmpty)
    }
}
