import XCTest
@testable import DiskPrune

final class SmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertFalse(SafetyRules.tier1Paths().isEmpty)
    }
}
