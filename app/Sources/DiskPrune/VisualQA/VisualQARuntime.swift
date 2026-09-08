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

    static func trace(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let log = outputRoot.appendingPathComponent("harness.log")
        try? FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: log) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? Data(line.utf8).write(to: log)
        }
        fputs(line, stderr)
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
        VisualQARuntime.trace("catalog scheduled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            do {
                try run(session: session)
                writeManifest()
                VisualQARuntime.trace("catalog complete shots=\(records.count)")
                try? Data("ok\n".utf8).write(to: VisualQARuntime.outputRoot.appendingPathComponent("DONE"))
                NSApp.terminate(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { exit(0) }
            } catch {
                VisualQARuntime.trace("VISUAL_QA_FAIL \(error)")
                writeManifest()
                try? Data("fail\n".utf8).write(to: VisualQARuntime.outputRoot.appendingPathComponent("DONE"))
                exit(1)
            }
        }
    }

    private static func run(session: AppSession) throws {
        try FileManager.default.createDirectory(at: VisualQARuntime.outputRoot, withIntermediateDirectories: true)
        for _ in 0..<40 {
            if NSApp.windows.contains(where: { $0.contentView != nil }) { break }
            spin(0.1)
        }
        guard NSApp.windows.first?.contentView != nil else { throw CaptureError.noWindow }
        VisualQARuntime.trace("window ready count=\(NSApp.windows.count)")

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
                try captureRendered(StorageAutopsyView(session: session), screen: "03-overview-autopsy", dark: dark, size: size, fixture: true)

                session.destination = .category(.developer)
                try captureRendered(ResultsView(session: session, filter: .bucket(.developer)), screen: "04-category-detail", dark: dark, size: size, fixture: true)

                session.destination = .cleanup
                session.inspectorOpen = false
                try captureRendered(ResultsView(session: session, filter: .cleanup), screen: "05-cleanup-candidates", dark: dark, size: size, fixture: true)

                if let item = session.items.first(where: { $0.safety == .safe }) {
                    try captureRendered(ItemDetailView(item: item, knowledge: knowledge), screen: "06-item-inspector", dark: dark, size: size, fixture: true)
                }

                session.destination = .snapshots
                try captureRendered(SnapshotView(summary: session.snapshots), screen: "07-snapshots", dark: dark, size: size, fixture: true)

                ingestEmpty(session)
                session.destination = .cleanup
                try captureRendered(ResultsView(session: session, filter: .cleanup), screen: "08-empty-no-candidates", dark: dark, size: size, fixture: true)

                ingest(session, partial: true)
                session.destination = .overview
                try captureRendered(StorageAutopsyView(session: session), screen: "09-overview-partial", dark: dark, size: size, fixture: true)

                ingest(session, partial: false)
                if let item = session.items.first(where: { $0.safety == .protected }) {
                    try captureRendered(ItemDetailView(item: item, knowledge: knowledge), screen: "10-inspector-protected", dark: dark, size: size, fixture: true)
                }
                if let item = session.items.first(where: { $0.safety == .advanced }) {
                    try captureRendered(ItemDetailView(item: item, knowledge: knowledge), screen: "11-inspector-advanced", dark: dark, size: size, fixture: true)
                }
            }

            ingest(session, partial: false)
            session.destination = .cleanup
            try captureRendered(DryRunSheet(session: session), screen: "12-dry-run", dark: dark, size: CGSize(width: 520, height: 400), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            try captureRendered(ReceiptView(receipt: successReceipt(knowledge)), screen: "13-receipt", dark: dark, size: CGSize(width: 560, height: 480), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            try captureRendered(ReceiptView(receipt: failureReceipt(knowledge)), screen: "14-cleanup-failure", dark: dark, size: CGSize(width: 560, height: 520), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            try captureRendered(SettingsRootView(knowledge: knowledge), screen: "15-settings", dark: dark, size: CGSize(width: 520, height: 360), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
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
        VisualQARuntime.trace("captured \(screen) dark=\(dark) \(Int(size.width))x\(Int(size.height))")
    }

    private static func captureRendered<V: View>(
        _ view: V,
        screen: String,
        dark: Bool,
        size: CGSize,
        fixture: Bool,
        folder: String? = nil
    ) throws {
        VisualQARuntime.trace("render \(screen) begin")
        applyAppearance(dark)
        let scheme: ColorScheme = dark ? .dark : .light
        let wrapped = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, scheme)
            .preferredColorScheme(scheme)
            .transaction { $0.animation = nil }
        let renderer = ImageRenderer(content: wrapped)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 2
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { throw CaptureError.blank(screen) }
        let dir = folder ?? "\(dark ? "dark" : "light")/\(Int(size.width))x\(Int(size.height))"
        try write(rep, relative: "\(dir)/\(screen).png", screen: screen, dark: dark, size: size, fixture: fixture, source: "production-view-ImageRenderer")
        VisualQARuntime.trace("captured \(screen) dark=\(dark) \(Int(size.width))x\(Int(size.height))")
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
        // examined == used so the capacity bar has no Canvas hatch in CI.
        // HatchSegment + cacheDisplay hung the runner after scan-progress.
        StorageCoverage(
            volumeTotalBytes: 100_000_000_000,
            volumeAvailableBytes: 14_000_000_000,
            classifiedBytes: empty ? 4_000_000_000 : 80_000_000_000,
            unclassifiedScannedBytes: empty ? 0 : 6_000_000_000,
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
