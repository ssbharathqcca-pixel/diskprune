import XCTest
@testable import DiskPrune

final class TerminologyTests: XCTestCase {
    func testTERM01_receiptAndPlanViewsDoNotSayFreed() throws {
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DiskPrune/UI")
        let files = ["ReceiptView.swift", "CleanupPlanView.swift"]
        for name in files {
            let url = ui.appendingPathComponent(name)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "missing \(name)")
            let text = try String(contentsOf: url, encoding: .utf8)
            for banned in ["freed", "reclaimed", "reclaim"] {
                XCTAssertFalse(
                    text.lowercased().contains(banned),
                    "\(name) contains forbidden term \(banned)"
                )
            }
        }
        let receipt = try String(contentsOf: ui.appendingPathComponent("ReceiptView.swift"), encoding: .utf8)
        XCTAssertTrue(receipt.contains("Estimated recoverable"))
        XCTAssertTrue(receipt.contains("Moved to Trash"))
        XCTAssertTrue(receipt.contains("Storage immediately available"))
        XCTAssertTrue(receipt.contains("Empty Trash to permanently remove these items from your Mac."))
        XCTAssertFalse(receipt.lowercased().contains("reclaim"))
    }
}
