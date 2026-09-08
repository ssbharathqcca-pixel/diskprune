import XCTest
@testable import DiskPrune

final class TerminologyTests: XCTestCase {
    func testTERM01_receiptAndPlanViewsDoNotSayFreed() throws {
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DiskPrune/UI")
        let files = ["ReceiptView.swift", "CleanupPlanView.swift"]
        for name in files {
            let url = ui.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            for banned in ["freed", "reclaimed"] {
                XCTAssertFalse(
                    text.lowercased().contains(banned),
                    "\(name) contains forbidden term \(banned)"
                )
            }
        }
    }
}
