import AppKit
import Foundation
import SwiftUI

/// In-process Visual QA harness. Dead unless `DISKPRUNE_VISUAL_QA=1`.
/// Does not execute CleanupExecutor, bypass TOCTOU, or open LicenseManager.
enum VisualQARuntime {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["DISKPRUNE_VISUAL_QA"] == "1"
    }

    static var outputRoot: URL {
        if let path = ProcessInfo.processInfo.environment["DISKPRUNE_VISUAL_QA_OUT"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("diskprune-visual-qa")
    }

    @MainActor
    static func root(knowledge: StorageKnowledge) -> some View {
        VisualQAHost(session: AppSession(knowledge: knowledge))
    }
}

@MainActor
private final class VisualQAHostModel: ObservableObject {
    let session: AppSession
    init(session: AppSession) { self.session = session }
}

private struct VisualQAHost: View {
    @StateObject private var model: VisualQAHostModel

    init(session: AppSession) {
        _model = StateObject(wrappedValue: VisualQAHostModel(session: session))
    }

    var body: some View {
        RootView(session: model.session)
            .onAppear { VisualQACatalog.schedule(session: model.session) }
    }
}

@MainActor
private enum VisualQACatalog {
    private static var started = false
    private static var records: [[String: String]] = []
    private static var limitations: [String] = [
        "Shots are taken from DiskPrune.app's own contentView (cacheDisplay), not ScreenCaptureKit.",
        "Gate 4 remains NOT PASS.",
    ]

    static func schedule(session: AppSession) {
        guard !started else { return }
        started = true
        PreferencesStore.scanOnLaunch = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            do {
                try run(session: session)
                writeManifest()
                fputs("VISUAL_QA_OUT=\(VisualQARuntime.outputRoot.path)\n", stderr)
                NSApp.terminate(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { exit(0) }
            } catch {
                fputs("VISUAL_QA_FAIL \(error)\n", stderr)
                exit(1)
            }
        }
    }

    private static func run(session: AppSession) throws {
        try FileManager.default.createDirectory(at: VisualQARuntime.outputRoot, withIntermediateDirectories: true)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for _ in 0..<25 {
            if NSApp.windows.contains(where: { $0.contentView != nil }) { break }
            spin(0.1)
        }
        guard NSApp.windows.first?.contentView != nil else { throw CaptureError.noWindow }
        let knowledge = session.knowledge
        let wide = CGSize(width: 1100, height: 720)
        let narrow = CGSize(width: 880, height: 560)

        for dark in [false, true] {
            applyAppearance(dark)
            for size in [wide, narrow] {
                session.phase = .idle
                session.coverage = nil
                session.items = []
                session.destination = .overview
                session.inspectorOpen = false
                session.showDryRun = false
                session.showReceipt = false
                try captureWindow("01-first-launch", dark: dark, size: size, fixture: false)

                session.phase = .scanning
                session.completedProbes = ["Xcode", "Docker"]
                session.activeProbe = "Package managers"
                session.probeBytes = ["Xcode": 38_400_000_000, "Docker": 8_100_000_000]
                try captureWindow("02-scan-progress", dark: dark, size: size, fixture: true)

                ingest(session, partial: false)
                session.destination = .overview
                try captureWindow("03-overview-autopsy", dark: dark, size: size, fixture: true)

                session.destination = .category(.developer)
                try captureWindow("04-category-detail", dark: dark, size: size, fixture: true)

                session.destination = .cleanup
                session.inspectorOpen = false
                try captureWindow("05-cleanup-candidates", dark: dark, size: size, fixture: true)

                if let item = session.items.first(where: { $0.safety == .safe }) {
                    session.openInspector(item)
                }
                try captureWindow("06-item-inspector", dark: dark, size: size, fixture: true)
                session.inspectorOpen = false

                session.destination = .snapshots
                try captureWindow("07-snapshots", dark: dark, size: size, fixture: true)

                ingestEmpty(session)
                session.destination = .cleanup
                try captureWindow("08-empty-no-candidates", dark: dark, size: size, fixture: true)

                ingest(session, partial: true)
                session.destination = .overview
                try captureWindow("09-overview-partial", dark: dark, size: size, fixture: true)

                ingest(session, partial: false)
                session.destination = .cleanup
                if let item = session.items.first(where: { $0.safety == .protected }) {
                    session.openInspector(item)
                }
                try captureWindow("10-inspector-protected", dark: dark, size: size, fixture: true)
                session.inspectorOpen = false
                if let item = session.items.first(where: { $0.safety == .advanced }) {
                    session.openInspector(item)
                }
                try captureWindow("11-inspector-advanced", dark: dark, size: size, fixture: true)
                session.inspectorOpen = false
            }

            ingest(session, partial: false)
            session.destination = .cleanup
            session.presentDryRun()
            spin(0.35)
            try captureWindow("12-dry-run", dark: dark, size: wide, fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            session.showDryRun = false

            session.receipt = successReceipt(knowledge)
            session.showReceipt = true
            spin(0.35)
            try captureWindow("13-receipt", dark: dark, size: wide, fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            session.showReceipt = false

            session.receipt = failureReceipt(knowledge)
            session.showReceipt = true
            spin(0.35)
            try captureWindow("14-cleanup-failure", dark: dark, size: wide, fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            session.showReceipt = false

            try captureStandalone(
                SettingsRootView(knowledge: knowledge),
                screen: "15-settings",
                dark: dark,
                size: CGSize(width: 520, height: 360)
            )
        }
    }

    private static func ingest(_ session: AppSession, partial: Bool) {
        session.ingestScan(
            items: catalogItems(session.knowledge),
            coverage: coverage(partial: partial, empty: false),
            snapshots: snapshots()
        )
    }

    private static func ingestEmpty(_ session: AppSession) {
        let knowledge = session.knowledge
        session.ingestScan(
            items: [
                item(knowledge, id: "protected-documents", ino: 31, bytes: 80_000_000_000),
                item(knowledge, id: "docker-raw", ino: 32, bytes: 4_000_000_000, logical: 20_000_000_000, type: .regularFile),
            ],
            coverage: coverage(partial: false, empty: true),
            snapshots: snapshots()
        )
    }

    private static func captureWindow(
        _ screen: String,
        dark: Bool,
        size: CGSize,
        fixture: Bool,
        folder: String? = nil
    ) throws {
        applyAppearance(dark)
        guard let window = NSApp.windows.first else {
            throw CaptureError.noWindow
        }
        window.setContentSize(size)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.displayIfNeeded()
        spin(0.3)
        guard let view = window.contentView else { throw CaptureError.noWindow }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CaptureError.blank(screen)
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        let dir = folder ?? "\(dark ? "dark" : "light")/\(Int(size.width))x\(Int(size.height))"
        try write(rep, relative: "\(dir)/\(screen).png", screen: screen, dark: dark, size: size, fixture: fixture, source: "DiskPrune.app-contentView")
    }

    private static func captureStandalone<V: View>(_ view: V, screen: String, dark: Bool, size: CGSize) throws {
        applyAppearance(dark)
        let scheme: ColorScheme = dark ? .dark : .light
        let wrapped = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, scheme)
            .preferredColorScheme(scheme)
        let renderer = ImageRenderer(content: wrapped)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 2
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { throw CaptureError.blank(screen) }
        try write(rep, relative: "sheets/\(dark ? "dark" : "light")/\(screen).png", screen: screen, dark: dark, size: size, fixture: true, source: "production-view-ImageRenderer")
    }

    private static func write(
        _ rep: NSBitmapImageRep,
        relative: String,
        screen: String,
        dark: Bool,
        size: CGSize,
        fixture: Bool,
        source: String
    ) throws {
        let url = VisualQARuntime.outputRoot.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let png = rep.representation(using: .png, properties: [:]), png.count > 2_000 else {
            throw CaptureError.blank(relative)
        }
        try png.write(to: url)
        records.append([
            "file": relative,
            "screen": screen,
            "theme": dark ? "dark" : "light",
            "size": "\(Int(size.width))x\(Int(size.height))",
            "source": source,
            "fixture": fixture ? "true" : "false",
        ])
    }

    private static func writeManifest() {
        let payload: [String: Any] = [
            "gate4": "NOT PASS",
            "note": "Supplemental screenshots from the packaged DiskPrune.app on macos-latest. Human review still required.",
            "shots": records,
            "limitations": limitations,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: VisualQARuntime.outputRoot.appendingPathComponent("manifest.json"))
        }
        var index = "DiskPrune Visual QA screenshots\nGate 4: NOT PASS (human review required)\n\n"
        for record in records {
            index += "- \(record["file"] ?? "")  [\(record["theme"] ?? "") \(record["size"] ?? "")] source=\(record["source"] ?? "") fixture=\(record["fixture"] ?? "")\n"
        }
        try? index.write(to: VisualQARuntime.outputRoot.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
    }

    private static func applyAppearance(_ dark: Bool) {
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }

    private static func spin(_ seconds: Double) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private static func catalogItems(_ knowledge: StorageKnowledge) -> [StorageItem] {
        [
            item(knowledge, id: "xcode-deriveddata", ino: 11, bytes: 38_400_000_000, extra: "DemoProject-cafef00d"),
            item(knowledge, id: "user-caches", ino: 12, bytes: 6_200_000_000),
            item(knowledge, id: "user-logs", ino: 13, bytes: 1_100_000_000),
            item(knowledge, id: "npm-cacache", ino: 14, bytes: 3_400_000_000),
            item(knowledge, id: "application-support", ino: 15, bytes: 8_800_000_000, extra: "com.apple.dt.Xcode"),
            item(knowledge, id: "xcode-simulators", ino: 16, bytes: 14_200_000_000),
            item(knowledge, id: "docker-raw", ino: 17, bytes: 8_100_000_000, logical: 64_424_509_440, type: .regularFile),
            item(knowledge, id: "protected-documents", ino: 18, bytes: 120_000_000_000),
        ]
    }

    private static func coverage(partial: Bool, empty: Bool) -> StorageCoverage {
        StorageCoverage(
            volumeTotalBytes: 1_000_000_000_000,
            volumeAvailableBytes: 258_000_000_000,
            classifiedBytes: empty ? 4_000_000_000 : 86_000_000_000,
            unclassifiedScannedBytes: 2_000_000_000,
            permissionLimitedPaths: partial ? ["/Users/qa/Library/Mail", "/Users/qa/Library/Messages"] : [],
            cleanupCandidateBytes: empty ? 0 : 12_400_000_000
        )
    }

    private static func snapshots() -> SnapshotSummary {
        SnapshotSummary(
            count: 3,
            dates: [
                Date(timeIntervalSince1970: 1_757_300_000),
                Date(timeIntervalSince1970: 1_757_386_400),
                Date(timeIntervalSince1970: 1_757_472_800),
            ],
            readFailed: false
        )
    }

    private static func successReceipt(_ knowledge: StorageKnowledge) -> CleanupReceipt {
        receipt(
            estimated: 4_200_000_000,
            trashed: 4_180_000_000,
            delta: 80_000,
            outcomes: [
                .trashed(itemID: UUID(), path: "/Users/qa/Library/Caches/com.apple.helpd", bytes: 2_100_000_000, resultingTrashURL: nil),
                .trashed(itemID: UUID(), path: "/Users/qa/Library/Developer/Xcode/DerivedData/DemoProject-cafef00d", bytes: 2_080_000_000, resultingTrashURL: nil),
            ],
            knowledge: knowledge
        )
    }

    private static func failureReceipt(_ knowledge: StorageKnowledge) -> CleanupReceipt {
        receipt(
            estimated: 1_800_000_000,
            trashed: 0,
            delta: 0,
            outcomes: [
                .failed(itemID: UUID(), path: "/Users/qa/Library/Logs/locked.log", bytes: 800_000_000, reason: .permissionDenied),
                .skipped(itemID: UUID(), path: "/Users/qa/Library/Caches/gone", bytes: 1_000_000_000, reason: .vanished),
            ],
            knowledge: knowledge
        )
    }

    private static func receipt(
        estimated: Int64,
        trashed: Int64,
        delta: Int64,
        outcomes: [ItemOutcome],
        knowledge: StorageKnowledge
    ) -> CleanupReceipt {
        let stamp = Date(timeIntervalSince1970: 1_757_350_000)
        return CleanupReceipt(
            id: UUID(),
            planID: UUID(),
            startedAt: stamp,
            finishedAt: stamp.addingTimeInterval(4),
            wasCancelled: false,
            estimatedRecoverableBytes: estimated,
            successfullyTrashedBytes: trashed,
            volumeAvailableBefore: 258_000_000_000,
            volumeAvailableAfter: 258_000_000_000 + delta,
            immediateAvailableDelta: delta,
            outcomes: outcomes,
            trashLocation: "/Users/qa/.Trash",
            appVersion: "1.0.0",
            rulesVersion: knowledge.rulesVersion
        )
    }

    private static func item(
        _ knowledge: StorageKnowledge,
        id: String,
        ino: UInt64,
        bytes: Int64,
        logical: Int64? = nil,
        type: ObjectType = .directory,
        extra: String? = nil
    ) -> StorageItem {
        guard let rule = knowledge.rule(id: id) else {
            preconditionFailure("storage-rules.json missing fixture id \(id)")
        }
        let root = knowledge.expandedPaths(for: rule).first ?? "/Users/qa/Library/Caches"
        let url = extra.map { URL(fileURLWithPath: root).appendingPathComponent($0) }
            ?? URL(fileURLWithPath: root)
        return StorageItem(
            url: url,
            fileID: FileID(dev: 1, ino: ino),
            objectType: type,
            displayName: extra ?? rule.displayName,
            onDiskBytes: bytes,
            logicalBytes: logical ?? bytes,
            fileCount: type == .regularFile ? 1 : 40,
            newestModification: Date(timeIntervalSince1970: 1_757_350_000),
            category: rule.category,
            safety: rule.safety,
            knowledgeID: rule.id,
            explanation: rule.explanation,
            consequence: rule.consequence,
            regenerable: rule.regenerable,
            cleanupRoot: URL(fileURLWithPath: root),
            scanState: .complete
        )
    }

    enum CaptureError: Error, CustomStringConvertible {
        case blank(String)
        case noWindow
        var description: String {
            switch self {
            case .blank(let name): return "blank screenshot: \(name)"
            case .noWindow: return "DiskPrune window missing"
            }
        }
    }
}
