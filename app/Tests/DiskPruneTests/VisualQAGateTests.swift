import XCTest
@testable import DiskPrune

final class VisualQAGateTests: XCTestCase {
    func testHarnessIsDisabledDuringUnitTests() {
        XCTAssertFalse(VisualQARuntime.isEnabled, "DISKPRUNE_VISUAL_QA must not be set in the unit-test job")
    }
}
