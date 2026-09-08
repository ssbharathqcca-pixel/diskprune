import AppKit
import SwiftUI
import XCTest
@testable import DiskPrune

/// Hosts production SwiftUI views in a real AppKit window and writes PNGs.
/// Skipped unless DISKPRUNE_VISUAL_QA=1 so ordinary `swift test` stays a unit suite.
@MainActor
final class VisualQATests: XCTestCase {
    private let wide = CGSize(width: 1100, height: 720)
    private let narrow = CGSize(width: 880, height: 560)

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["DISKPRUNE_VISUAL_QA"] == "1",
            "Set DISKPRUNE_VISUAL_QA=1 to capture production UI screenshots"
        )
        VisualQACapture.bootstrap()
    }

    func testCaptureProductionUICatalog() async throws {
        VisualQACapture.records = []
        VisualQACapture.limitations = []

        for dark in [false, true] {
            for size in [wide, narrow] {
                try captureFirstLaunch(dark: dark, size: size)
                try captureScan(dark: dark, size: size)
                try captureOverview(partial: false, dark: dark, size: size)
                try captureCategory(dark: dark, size: size)
                try captureCleanup(dark: dark, size: size)
                try captureInspector(kind: .safe, dark: dark, size: size)
                try captureSnapshots(dark: dark, size: size)
                try captureEmpty(dark: dark, size: size)
                try captureOverview(partial: true, dark: dark, size: size)
                try captureInspector(kind: .protected, dark: dark, size: size)
                try captureInspector(kind: .advanced, dark: dark, size: size)
            }
            try captureSheets(dark: dark)
        }

        if let appPath = ProcessInfo.processInfo.environment["DISKPRUNE_APP"], !appPath.isEmpty {
            let url = URL(fileURLWithPath: appPath)
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    try await VisualQACapture.captureRealApp(at: url)
                } catch {
                    VisualQACapture.limitations.append("Packaged app launch: \(error)")
                }
            } else {
                VisualQACapture.limitations.append("DISKPRUNE_APP does not exist at \(appPath)")
            }
        } else {
            VisualQACapture.limitations.append("DISKPRUNE_APP not set — packaged first-launch screenshot skipped")
        }

        try VisualQACapture.writeManifest()
        XCTAssertGreaterThanOrEqual(VisualQACapture.records.count, 20, "too few screenshots written")
        let out = VisualQACapture.outputRoot.path
        print("VISUAL_QA_OUT=\(out)")
    }

    private func captureFirstLaunch(dark: Bool, size: CGSize) throws {
        let session = try VisualQAFixtures.session()
        try VisualQACapture.captureRoot(session, screen: "01-first-launch", dark: dark, size: size, fixture: false)
    }

    private func captureScan(dark: Bool, size: CGSize) throws {
        let session = try VisualQAFixtures.scanningSession()
        try VisualQACapture.captureRoot(session, screen: "02-scan-progress", dark: dark, size: size, fixture: true)
    }

    private func captureOverview(partial: Bool, dark: Bool, size: CGSize) throws {
        let session = try VisualQAFixtures.readySession(partial: partial)
        session.destination = .overview
        let name = partial ? "09-overview-partial" : "03-overview-autopsy"
        try VisualQACapture.captureRoot(session, screen: name, dark: dark, size: size, fixture: true)
    }

    private func captureCategory(dark: Bool, size: CGSize) throws {
        let session = try VisualQAFixtures.readySession()
        session.destination = .category(.developer)
        try VisualQACapture.captureRoot(session, screen: "04-category-detail", dark: dark, size: size, fixture: true)
    }

    private func captureCleanup(dark: Bool, size: CGSize) throws {
        let session = try VisualQAFixtures.readySession()
        session.destination = .cleanup
        try VisualQACapture.captureRoot(session, screen: "05-cleanup-candidates", dark: dark, size: size, fixture: true)
    }

    private enum InspectorKind { case safe, protected, advanced }

    private func captureInspector(kind: InspectorKind, dark: Bool, size: CGSize) throws {
        let session = try VisualQAFixtures.readySession()
        session.destination = .cleanup
        let item: StorageItem?
        let name: String
        switch kind {
        case .safe:
            item = session.items.first { $0.safety == .safe }
            name = "06-item-inspector"
        case .protected:
            item = session.items.first { $0.safety == .protected }
            name = "10-inspector-protected"
        case .advanced:
            item = session.items.first { $0.safety == .advanced }
            name = "11-inspector-advanced"
        }
        XCTAssertNotNil(item, "fixture catalog missing \(kind) item")
        if let item {
            session.openInspector(item)
        }
        try VisualQACapture.captureRoot(session, screen: name, dark: dark, size: size, fixture: true)
    }

    private func captureSnapshots(dark: Bool, size: CGSize) throws {
        let session = try VisualQAFixtures.readySession()
        session.destination = .snapshots
        try VisualQACapture.captureRoot(session, screen: "07-snapshots", dark: dark, size: size, fixture: true)
    }

    private func captureEmpty(dark: Bool, size: CGSize) throws {
        let session = try VisualQAFixtures.emptyCandidatesSession()
        session.destination = .cleanup
        try VisualQACapture.captureRoot(session, screen: "08-empty-no-candidates", dark: dark, size: size, fixture: true)
    }

    private func captureSheets(dark: Bool) throws {
        let session = try VisualQAFixtures.readySession()
        session.destination = .cleanup
        try VisualQACapture.captureStandalone(
            DryRunSheet(session: session),
            screen: "12-dry-run",
            dark: dark,
            size: CGSize(width: 520, height: 400)
        )
        try VisualQACapture.captureStandalone(
            ReceiptView(receipt: VisualQAFixtures.successReceipt()),
            screen: "13-receipt",
            dark: dark,
            size: CGSize(width: 560, height: 480)
        )
        try VisualQACapture.captureStandalone(
            ReceiptView(receipt: VisualQAFixtures.failureReceipt()),
            screen: "14-cleanup-failure",
            dark: dark,
            size: CGSize(width: 560, height: 520)
        )
        try VisualQACapture.captureStandalone(
            SettingsRootView(knowledge: try VisualQAFixtures.knowledge()),
            screen: "15-settings",
            dark: dark,
            size: CGSize(width: 520, height: 360)
        )
    }
}
