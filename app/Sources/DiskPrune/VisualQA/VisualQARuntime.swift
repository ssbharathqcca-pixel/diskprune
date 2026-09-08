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
        "Gate 4 remains NOT PASS.",
        "ImageRenderer is not used: on macOS it draws List/TabView/Form as a yellow prohibition placeholder.",
        "Shots are NSHostingView in a real NSWindow, flattened with displayIgnoringOpacity.",
    ]
    private static var captureWindow: NSWindow?

    static func schedule(session: AppSession) {
        guard !started else { return }
        started = true
        PreferencesStore.scanOnLaunch = false
        VisualQARuntime.trace("catalog scheduled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            do {
                try run(session: session)
                finish(ok: true)
            } catch {
                VisualQARuntime.trace("VISUAL_QA_FAIL \(error)")
                limitations.append("catalog error: \(error)")
                finish(ok: false)
            }
        }
    }

    private static func finish(ok: Bool) {
        writeManifest()
        try? Data((ok ? "ok\n" : "fail\n").utf8).write(to: VisualQARuntime.outputRoot.appendingPathComponent("DONE"))
        try? Data("complete\n".utf8).write(to: VisualQARuntime.outputRoot.appendingPathComponent("COMPLETE"))
        VisualQARuntime.trace("catalog complete shots=\(records.count) ok=\(ok)")
        captureWindow?.orderOut(nil)
        captureWindow?.close()
        captureWindow = nil
        NSApp.terminate(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { exit(ok ? 0 : 1) }
    }

    private static func run(session: AppSession) throws {
        try FileManager.default.createDirectory(at: VisualQARuntime.outputRoot, withIntermediateDirectories: true)
        _ = session
        let knowledge = try StorageKnowledge.load()
        let wide = CGSize(width: 1100, height: 720)
        let narrow = CGSize(width: 880, height: 560)

        let fixture = AppSession(knowledge: knowledge)
        ingest(fixture, partial: false)
        let empty = AppSession(knowledge: knowledge)
        ingestEmpty(empty)
        let partial = AppSession(knowledge: knowledge)
        ingest(partial, partial: true)

        for dark in [false, true] {
            for size in [wide, narrow] {
                let idle = AppSession(knowledge: knowledge)
                try captureHosted(RootView(session: idle), screen: "01-first-launch", dark: dark, size: size, fixture: false)

                let scanning = AppSession(knowledge: knowledge)
                scanning.phase = .scanning
                scanning.completedProbes = ["Xcode", "Docker"]
                scanning.activeProbe = "Package managers"
                scanning.probeBytes = ["Xcode": 38_400_000_000, "Docker": 8_100_000_000]
                try captureHosted(RootView(session: scanning), screen: "02-scan-progress", dark: dark, size: size, fixture: true)

                fixture.destination = .category(.developer)
                fixture.inspectorOpen = false
                try captureHosted(RootView(session: fixture), screen: "04-category-detail", dark: dark, size: size, fixture: true)

                fixture.destination = .cleanup
                try captureHosted(RootView(session: fixture), screen: "05-cleanup-candidates", dark: dark, size: size, fixture: true)

                if let item = fixture.items.first(where: { $0.safety == .safe }) {
                    fixture.openInspector(item)
                    try captureHosted(RootView(session: fixture), screen: "06-item-inspector", dark: dark, size: size, fixture: true)
                    fixture.inspectorOpen = false
                }

                fixture.destination = .snapshots
                try captureHosted(RootView(session: fixture), screen: "07-snapshots", dark: dark, size: size, fixture: true)

                empty.destination = .cleanup
                try captureHosted(RootView(session: empty), screen: "08-empty-no-candidates", dark: dark, size: size, fixture: true)

                if let item = fixture.items.first(where: { $0.safety == .protected }) {
                    fixture.destination = .cleanup
                    fixture.openInspector(item)
                    try captureHosted(RootView(session: fixture), screen: "10-inspector-protected", dark: dark, size: size, fixture: true)
                    fixture.inspectorOpen = false
                }
                if let item = fixture.items.first(where: { $0.safety == .advanced }) {
                    fixture.destination = .cleanup
                    fixture.openInspector(item)
                    try captureHosted(RootView(session: fixture), screen: "11-inspector-advanced", dark: dark, size: size, fixture: true)
                    fixture.inspectorOpen = false
                }
            }

            try captureHosted(DryRunSheet(session: fixture), screen: "12-dry-run", dark: dark, size: CGSize(width: 520, height: 400), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            try captureHosted(ReceiptView(receipt: successReceipt(knowledge)), screen: "13-receipt", dark: dark, size: CGSize(width: 560, height: 480), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            try captureHosted(ReceiptView(receipt: failureReceipt(knowledge)), screen: "14-cleanup-failure", dark: dark, size: CGSize(width: 560, height: 520), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            try captureHosted(SettingsRootView(knowledge: knowledge), screen: "15-settings", dark: dark, size: CGSize(width: 520, height: 360), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
        }

        writeManifest()
        try? Data("checkpoint\n".utf8).write(to: VisualQARuntime.outputRoot.appendingPathComponent("DONE"))
        VisualQARuntime.trace("checkpoint before autopsy")

        fixture.destination = .overview
        try captureHosted(RootView(session: fixture), screen: "03-overview-autopsy", dark: false, size: wide, fixture: true)
        try captureHosted(RootView(session: fixture), screen: "03-overview-autopsy", dark: true, size: wide, fixture: true)
        try captureHosted(StorageAutopsyView(session: fixture), screen: "03b-autopsy-detail", dark: false, size: wide, fixture: true)
        partial.destination = .overview
        try captureHosted(RootView(session: partial), screen: "09-overview-partial", dark: false, size: wide, fixture: true)
        try captureHosted(RootView(session: partial), screen: "09-overview-partial", dark: true, size: wide, fixture: true)
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

    private static func captureHosted<V: View>(
        _ view: V,
        screen: String,
        dark: Bool,
        size: CGSize,
        fixture: Bool,
        folder: String? = nil
    ) throws {
        VisualQARuntime.trace("render \(screen) begin dark=\(dark) \(Int(size.width))x\(Int(size.height))")
        applyAppearance(dark)
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua) ?? NSAppearance(named: .aqua)!
        let scheme: ColorScheme = dark ? .dark : .light
        let wrapped = view
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, scheme)
            .preferredColorScheme(scheme)
            .transaction { $0.animation = nil }

        let hosting = NSHostingView(rootView: wrapped)
        hosting.appearance = appearance
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = reusableWindow(size: size, appearance: appearance)
        window.contentView = hosting
        window.setContentSize(size)
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()
        window.displayIfNeeded()
        spin(0.5)

        let target = window.contentView ?? hosting
        let rep = try flatten(target)
        try rejectIfInvalid(rep, screen: screen)
        let dir = folder ?? "\(dark ? "dark" : "light")/\(Int(size.width))x\(Int(size.height))"
        try write(rep, relative: "\(dir)/\(screen).png", screen: screen, dark: dark, size: size, fixture: fixture, source: "NSHostingView-window")
        VisualQARuntime.trace("captured \(screen) dark=\(dark) \(Int(size.width))x\(Int(size.height))")
    }

    private static func reusableWindow(size: CGSize, appearance: NSAppearance) -> NSWindow {
        if let window = captureWindow {
            window.appearance = appearance
            window.backgroundColor = .windowBackgroundColor
            window.setContentSize(size)
            return window
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DiskPrune"
        window.appearance = appearance
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: 60, y: 60))
        captureWindow = window
        return window
    }

    private static func flatten(_ view: NSView) throws -> NSBitmapImageRep {
        let bounds = view.bounds
        guard bounds.width > 8, bounds.height > 8 else { throw CaptureError.blank("zero-bounds") }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        for sub in view.subviews { sub.displayIfNeeded() }

        let scale = max(view.window?.backingScaleFactor ?? 2, 1)
        let pw = max(Int((bounds.width * scale).rounded()), 1)
        let ph = max(Int((bounds.height * scale).rounded()), 1)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pw,
            pixelsHigh: ph,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { throw CaptureError.png }
        rep.size = bounds.size

        guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else { throw CaptureError.png }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: bounds.size))
        view.displayIgnoringOpacity(bounds, in: graphics)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func rejectIfInvalid(_ rep: NSBitmapImageRep, screen: String) throws {
        guard let data = rep.bitmapData else { throw CaptureError.blank(screen) }
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let bpp = max(rep.bitsPerPixel / 8, 1)
        let bytesPerRow = rep.bytesPerRow
        var yellow = 0
        var opaque = 0
        var samples = 0
        for y in Swift.stride(from: 0, to: height, by: 12) {
            for x in Swift.stride(from: 0, to: width, by: 12) {
                samples += 1
                let pixel = data + y * bytesPerRow + x * bpp
                let r = Int(pixel[0])
                let g = Int(pixel[1])
                let b = bpp > 2 ? Int(pixel[2]) : r
                let a = bpp >= 4 ? Int(pixel[3]) : 255
                if a > 24 { opaque += 1 }
                if r > 200 && g > 170 && b < 90 { yellow += 1 }
            }
        }
        if samples == 0 { throw CaptureError.blank(screen) }
        if yellow * 100 / samples > 12 {
            throw CaptureError.placeholder(screen)
        }
        if opaque * 100 / samples < 12 {
            throw CaptureError.blank(screen)
        }
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
            "note": "Supplemental screenshots from production views hosted in a real NSWindow. Human review still required. ImageRenderer is not used.",
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
        if !limitations.isEmpty {
            index += "\nLimitations:\n"
            for line in limitations { index += "- \(line)\n" }
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
        case placeholder(String)
        case png
        case noWindow
        var description: String {
            switch self {
            case .blank(let name): return "blank screenshot: \(name)"
            case .placeholder(let name): return "yellow ImageRenderer placeholder: \(name)"
            case .png: return "could not encode PNG"
            case .noWindow: return "DiskPrune window missing"
            }
        }
    }
}
