import AppKit
import Darwin
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
        "Gate 4 remains NOT PASS. These PNGs are supplemental evidence for a human reviewer.",
        "ImageRenderer is not used (List/TabView/Form render as a yellow prohibition placeholder).",
        "displayIgnoringOpacity / cacheDisplay of a second hosted RootView is not used (hangs on List).",
        "RootView shots flatten the live window with CALayer.render first so a PNG is always on disk. Full-window cacheDisplay of NSVisualEffectView is not used (canDrawSubviewsIntoLayer hung bcc2b49e; CALayer.render drops sidebar vibrancy).",
        "If the left 240pt column is blank, try CGWindowListCreateImage (real window-server pixels). If TCC denies it, live NSTableView cell labels are composited at their real frames — capture recovery, not a second UI.",
        "Sheets and inspector detail are production views hosted in an auxiliary on-screen NSWindow.",
    ]
    private static var auxWindow: NSWindow?

    static func schedule(session: AppSession) {
        guard !started else { return }
        started = true
        PreferencesStore.scanOnLaunch = false
        VisualQARuntime.trace("catalog scheduled")
        startWatchdog()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            do {
                try run(live: session)
                finish(ok: true, reason: "ok")
            } catch {
                VisualQARuntime.trace("VISUAL_QA_FAIL \(error)")
                limitations.append("catalog error: \(error)")
                finish(ok: false, reason: "fail")
            }
        }
    }

    private static func startWatchdog() {
        let root = VisualQARuntime.outputRoot
        DispatchQueue.global(qos: .userInitiated).async {
            Thread.sleep(forTimeInterval: 200)
            let complete = root.appendingPathComponent("COMPLETE")
            if FileManager.default.fileExists(atPath: complete.path) { return }
            VisualQARuntime.trace("watchdog firing — writing COMPLETE so CI can collect partial shots")
            try? Data("watchdog\n".utf8).write(to: complete)
            let done = root.appendingPathComponent("DONE")
            if !FileManager.default.fileExists(atPath: done.path) {
                try? Data("watchdog\n".utf8).write(to: done)
            }
            _exit(0)
        }
    }

    private static func finish(ok: Bool, reason: String) {
        writeManifest()
        try? Data("\(reason)\n".utf8).write(to: VisualQARuntime.outputRoot.appendingPathComponent("DONE"))
        try? Data("\(reason)\n".utf8).write(to: VisualQARuntime.outputRoot.appendingPathComponent("COMPLETE"))
        VisualQARuntime.trace("catalog complete shots=\(records.count) ok=\(ok) reason=\(reason)")
        auxWindow?.orderOut(nil)
        auxWindow?.close()
        auxWindow = nil
        NSApp.terminate(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { exit(ok ? 0 : 1) }
    }

    private static func run(live: AppSession) throws {
        try FileManager.default.createDirectory(at: VisualQARuntime.outputRoot, withIntermediateDirectories: true)
        for _ in 0..<50 {
            if mainWindow() != nil { break }
            spin(0.1)
        }
        guard let window = mainWindow() else { throw CaptureError.noWindow }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        VisualQARuntime.trace("window ready title=\(window.title) count=\(NSApp.windows.count)")

        let knowledge = live.knowledge
        let wide = CGSize(width: 1100, height: 720)
        let narrow = CGSize(width: 880, height: 560)
        let fixture = AppSession(knowledge: knowledge)
        ingest(fixture, partial: false)

        // Phase A: live idle/scan + hosted production child views. No List-backed RootView.
        for dark in [false, true] {
            applyAppearance(dark)
            for size in [wide, narrow] {
                resetIdle(live)
                attemptLive(window, screen: "01-first-launch", dark: dark, size: size, fixture: false)

                applyScanProgress(live)
                attemptLive(window, screen: "02-scan-progress", dark: dark, size: size, fixture: true)
                resetIdle(live)

                if let item = fixture.items.first(where: { $0.safety == .safe }) {
                    attemptHosted(ItemDetailView(item: item, knowledge: knowledge), screen: "06-item-inspector", dark: dark, size: CGSize(width: 420, height: 640), fixture: true)
                }
                attemptHosted(SnapshotView(summary: SnapshotSummary(count: 0, dates: [], readFailed: false)), screen: "07-snapshots", dark: dark, size: size, fixture: true)
                if let item = fixture.items.first(where: { $0.safety == .protected }) {
                    attemptHosted(ItemDetailView(item: item, knowledge: knowledge), screen: "10-inspector-protected", dark: dark, size: CGSize(width: 420, height: 640), fixture: true)
                }
                if let item = fixture.items.first(where: { $0.safety == .advanced }) {
                    attemptHosted(ItemDetailView(item: item, knowledge: knowledge), screen: "11-inspector-advanced", dark: dark, size: CGSize(width: 420, height: 640), fixture: true)
                }
            }
            attemptHosted(DryRunSheet(session: fixture), screen: "12-dry-run", dark: dark, size: CGSize(width: 520, height: 400), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            attemptHosted(ReceiptView(receipt: successReceipt(knowledge)), screen: "13-receipt", dark: dark, size: CGSize(width: 560, height: 480), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            attemptHosted(ReceiptView(receipt: failureReceipt(knowledge)), screen: "14-cleanup-failure", dark: dark, size: CGSize(width: 560, height: 520), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
            attemptHosted(SettingsRootView(knowledge: knowledge), screen: "15-settings", dark: dark, size: CGSize(width: 520, height: 360), fixture: true, folder: "sheets/\(dark ? "dark" : "light")")
        }

        writeManifest()
        try? Data("checkpoint-before-data-views\n".utf8).write(to: VisualQARuntime.outputRoot.appendingPathComponent("DONE"))
        VisualQARuntime.trace("checkpoint before data views shots=\(records.count)")

        // Phase B: production child views with fixture data. Not a second RootView.
        // Live ingestScan previously hung because destination was still .overview
        // (StorageAutopsyView + hatch + sidebar Storage section in one update).
        let empty = AppSession(knowledge: knowledge)
        ingestEmpty(empty)
        let partialSession = AppSession(knowledge: knowledge)
        ingest(partialSession, partial: true)

        for dark in [false, true] {
            applyAppearance(dark)
            for size in [wide, narrow] {
                fixture.destination = .category(.developer)
                fixture.inspectorOpen = false
                attemptHosted(ResultsView(session: fixture, filter: .bucket(.developer)), screen: "04-category-detail", dark: dark, size: size, fixture: true, preferLayer: true)

                fixture.destination = .cleanup
                attemptHosted(ResultsView(session: fixture, filter: .cleanup), screen: "05-cleanup-candidates", dark: dark, size: size, fixture: true, preferLayer: true)

                attemptHosted(SnapshotView(summary: fixture.snapshots), screen: "07b-snapshots-list", dark: dark, size: size, fixture: true, preferLayer: true)

                empty.destination = .cleanup
                attemptHosted(ResultsView(session: empty, filter: .cleanup), screen: "08-empty-no-candidates", dark: dark, size: size, fixture: true, preferLayer: true)
            }
            fixture.destination = .overview
            attemptHosted(StorageAutopsyView(session: fixture), screen: "03-overview-autopsy", dark: dark, size: wide, fixture: true, preferLayer: true)
            partialSession.destination = .overview
            attemptHosted(StorageAutopsyView(session: partialSession), screen: "09-overview-partial", dark: dark, size: wide, fixture: true, preferLayer: true)
        }

        writeManifest()
        try? Data("checkpoint-before-live-ingest\n".utf8).write(to: VisualQARuntime.outputRoot.appendingPathComponent("DONE"))
        VisualQARuntime.trace("checkpoint before live ingest shots=\(records.count)")

        // Phase C: live RootView after ingest. Switch off Overview first so Autopsy
        // is not the first paint. cacheDisplay, no displayIfNeeded.
        applyAppearance(false)
        live.destination = .cleanup
        live.phase = .ready
        live.coverage = nil
        live.items = []
        waitForLayout(window, size: wide, flush: false)
        VisualQARuntime.trace("live ingest begin dest=\(String(describing: live.destination))")
        ingest(live, partial: false)
        live.destination = .cleanup
        live.inspectorOpen = false
        VisualQARuntime.trace("live ingest returned items=\(live.items.count)")
        waitForLayout(window, size: wide, flush: false)
        proveSidebar(window)
        attemptLive(window, screen: "05b-cleanup-in-root", dark: false, size: wide, fixture: true)

        live.destination = .category(.developer)
        waitForLayout(window, size: wide, flush: false)
        attemptLive(window, screen: "04b-category-in-root", dark: false, size: wide, fixture: true)

        live.destination = .overview
        waitForLayout(window, size: wide, flush: false)
        attemptLive(window, screen: "03b-autopsy-in-root", dark: false, size: wide, fixture: true)

        if let item = live.items.first(where: { $0.safety == .safe }) {
            live.destination = .cleanup
            live.openInspector(item)
            waitForLayout(window, size: wide, flush: false)
            attemptLive(window, screen: "06b-inspector-in-root", dark: false, size: wide, fixture: true)
            live.inspectorOpen = false
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

    private static func resetIdle(_ session: AppSession) {
        session.phase = .idle
        session.destination = .overview
        session.items = []
        session.coverage = nil
        session.snapshots = nil
        session.selectedIDs = []
        session.inspectorOpen = false
        session.selectedDetail = nil
        session.showDryRun = false
        session.showReceipt = false
        session.receipt = nil
        session.activeProbe = nil
        session.completedProbes = []
        session.probeBytes = [:]
        session.searchText = ""
        session.scanCancelled = false
    }

    private static func applyScanProgress(_ session: AppSession) {
        session.phase = .scanning
        session.destination = .overview
        session.completedProbes = ["Xcode", "Docker"]
        session.activeProbe = "Package managers"
        session.probeBytes = ["Xcode": 38_400_000_000, "Docker": 8_100_000_000]
        session.inspectorOpen = false
        session.showDryRun = false
        session.showReceipt = false
    }

    private static func attemptLive(_ window: NSWindow, screen: String, dark: Bool, size: CGSize, fixture: Bool) {
        do {
            try captureLive(window, screen: screen, dark: dark, size: size, fixture: fixture)
        } catch {
            VisualQARuntime.trace("SKIP \(screen) live \(error)")
            limitations.append("\(screen) \(dark ? "dark" : "light") \(Int(size.width))x\(Int(size.height)): \(error)")
        }
    }

    private static func attemptHosted<V: View>(_ view: V, screen: String, dark: Bool, size: CGSize, fixture: Bool, folder: String? = nil, preferLayer: Bool = true) {
        do {
            try captureHosted(view, screen: screen, dark: dark, size: size, fixture: fixture, folder: folder, preferLayer: preferLayer)
        } catch {
            VisualQARuntime.trace("SKIP \(screen) hosted \(error)")
            limitations.append("\(screen) \(dark ? "dark" : "light") \(Int(size.width))x\(Int(size.height)): \(error)")
        }
    }

    private static func captureLive(_ window: NSWindow, screen: String, dark: Bool, size: CGSize, fixture: Bool) throws {
        VisualQARuntime.trace("live \(screen) begin dark=\(dark) \(Int(size.width))x\(Int(size.height))")
        applyAppearance(dark)
        waitForLayout(window, size: size, flush: false)
        guard let view = window.contentView else { throw CaptureError.noWindow }

        // Layer snapshot first and on disk — never hang the catalog with 0 PNGs.
        // Do not set canDrawSubviewsIntoLayer (that hung bcc2b49e).
        var rep = try flattenLayerFallback(view)
        let dir = "\(dark ? "dark" : "light")/\(Int(size.width))x\(Int(size.height))"
        var source = "live-window-layer"
        try write(rep, relative: "\(dir)/\(screen).png", screen: screen, dark: dark, size: size, fixture: fixture, source: source)
        VisualQARuntime.trace("captured \(screen) layer dark=\(dark) \(Int(size.width))x\(Int(size.height))")

        if screen.hasPrefix("01-") || screen.hasPrefix("02-") { proveSidebar(window) }

        if leftColumnIsBlank(rep) {
            VisualQARuntime.trace("left column blank on \(screen); trying CGWindowListCreateImage then live NSTableView cells")
            if let server = windowServerSnapshot(window), !leftColumnIsBlank(server) {
                rep = server
                source = "live-window-CGWindowList"
            } else {
                compositeSidebarFromLiveHierarchy(onto: &rep, window: window)
                source = "live-window-layer+sidebar-cells"
            }
            try rejectIfInvalid(rep, screen: screen)
            try write(rep, relative: "\(dir)/\(screen).png", screen: screen, dark: dark, size: size, fixture: fixture, source: source)
        }
        VisualQARuntime.trace("captured \(screen) live dark=\(dark) \(Int(size.width))x\(Int(size.height)) source=\(source)")
    }

    private static func captureHosted<V: View>(
        _ view: V,
        screen: String,
        dark: Bool,
        size: CGSize,
        fixture: Bool,
        folder: String? = nil,
        preferLayer: Bool = true
    ) throws {
        VisualQARuntime.trace("hosted \(screen) begin dark=\(dark) \(Int(size.width))x\(Int(size.height))")
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
        hosting.wantsLayer = true

        let window = reusableAux(size: size, appearance: appearance)
        window.contentView = hosting
        window.setContentSize(size)
        window.orderFrontRegardless()
        waitForLayout(window, size: size, flush: false)

        let target = window.contentView ?? hosting
        let rep = preferLayer ? try flattenLayerFallback(target) : try flattenView(target)
        try rejectIfInvalid(rep, screen: screen)
        let dir = folder ?? "\(dark ? "dark" : "light")/\(Int(size.width))x\(Int(size.height))"
        try write(rep, relative: "\(dir)/\(screen).png", screen: screen, dark: dark, size: size, fixture: fixture, source: preferLayer ? "hosted-production-view-layer" : "hosted-production-view-cacheDisplay")
        VisualQARuntime.trace("captured \(screen) hosted dark=\(dark) \(Int(size.width))x\(Int(size.height))")
    }

    private static func reusableAux(size: CGSize, appearance: NSAppearance) -> NSWindow {
        if let window = auxWindow {
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
        window.title = "DiskPrune Visual QA"
        window.appearance = appearance
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: 80, y: 40))
        auxWindow = window
        return window
    }

    private static func mainWindow() -> NSWindow? {
        let titled = NSApp.windows.filter { $0.contentView != nil && $0.styleMask.contains(.titled) }
        if let match = titled.first(where: { $0.frame.width >= 800 && !$0.title.contains("Visual QA") }) {
            return match
        }
        if let match = titled.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) {
            return match
        }
        return NSApp.windows.first(where: { $0.contentView != nil })
    }

    private static func waitForLayout(_ window: NSWindow, size: CGSize, flush: Bool = false) {
        window.appearance = NSApp.appearance
        window.setContentSize(size)
        window.makeKeyAndOrderFront(nil)
        spin(0.45)
        if flush {
            window.contentView?.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }
    }

    private static func proveSidebar(_ window: NSWindow) {
        var labels: [String] = []
        var effects = 0
        var tables = 0
        func walk(_ view: NSView) {
            if view is NSVisualEffectView { effects += 1 }
            if let table = view as? NSTableView {
                tables += 1
                VisualQARuntime.trace("NSTableView rows=\(table.numberOfRows) frame=\(table.frame) class=\(type(of: table))")
                for row in 0..<table.numberOfRows {
                    if let cell = table.view(atColumn: 0, row: row, makeIfNecessary: true) {
                        collectText(cell, into: &labels)
                        if let accessibility = cell.accessibilityLabel(), !accessibility.isEmpty, !labels.contains(accessibility) {
                            labels.append(accessibility)
                        }
                    }
                }
            }
            if let field = view as? NSTextField, !field.stringValue.isEmpty {
                labels.append(field.stringValue)
            }
            for sub in view.subviews { walk(sub) }
        }
        if let root = window.contentView { walk(root) }
        let unique = labels.reduce(into: [String]()) { acc, item in
            if !acc.contains(item) { acc.append(item) }
        }
        VisualQARuntime.trace("sidebar proof effects=\(effects) tables=\(tables) labels=\(unique.joined(separator: " | "))")
        limitations.append("sidebar view dump: effects=\(effects) tables=\(tables) labels=\(unique.joined(separator: ", "))")
    }

    private static func collectText(_ view: NSView, into labels: inout [String]) {
        if let field = view as? NSTextField, !field.stringValue.isEmpty, !labels.contains(field.stringValue) {
            labels.append(field.stringValue)
        }
        if view.subviews.isEmpty, let label = view.accessibilityLabel(), !label.isEmpty, !labels.contains(label) {
            labels.append(label)
        }
        for sub in view.subviews { collectText(sub, into: &labels) }
    }

    /// cacheDisplay of a hosted child view. Does not mutate NSVisualEffectView.
    private static func flattenView(_ view: NSView) throws -> NSBitmapImageRep {
        view.layoutSubtreeIfNeeded()
        if let cached = try? cacheDisplayOnly(view) {
            return cached
        }
        return try flattenLayerFallback(view)
    }

    private static func cacheDisplayOnly(_ view: NSView) throws -> NSBitmapImageRep {
        let bounds = view.bounds
        guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 8, bounds.height > 8 else {
            throw CaptureError.blank("zero-bounds")
        }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { throw CaptureError.png }
        view.cacheDisplay(in: bounds, to: rep)
        return rep
    }

    private static func leftColumnIsBlank(_ rep: NSBitmapImageRep, points: CGFloat = 240) -> Bool {
        guard let data = rep.bitmapData else { return true }
        let scale = max(CGFloat(rep.pixelsWide) / max(rep.size.width, 1), 1)
        let width = min(Int((points * scale).rounded()), rep.pixelsWide / 2)
        let height = rep.pixelsHigh
        let bpp = max(rep.bitsPerPixel / 8, 1)
        let bytesPerRow = rep.bytesPerRow
        var minL = 255
        var maxL = 0
        var samples = 0
        for y in Swift.stride(from: 0, to: height, by: 8) {
            for x in Swift.stride(from: 0, to: width, by: 8) {
                samples += 1
                let pixel = data + y * bytesPerRow + x * bpp
                let l = (Int(pixel[0]) + Int(pixel[1]) + Int(bpp > 2 ? pixel[2] : pixel[0])) / 3
                minL = min(minL, l)
                maxL = max(maxL, l)
            }
        }
        return samples == 0 || (maxL - minL) < 12
    }

    private static func flattenLayerFallback(_ view: NSView) throws -> NSBitmapImageRep {
        view.wantsLayer = true
        view.layoutSubtreeIfNeeded()
        guard let layer = view.layer else { throw CaptureError.noWindow }
        let bounds = view.bounds
        guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 8, bounds.height > 8 else {
            throw CaptureError.blank("zero-bounds")
        }
        let scale = max(view.window?.backingScaleFactor ?? 2, 1)
        let pw = max(Int((bounds.width * scale).rounded()), 1)
        let ph = max(Int((bounds.height * scale).rounded()), 1)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: pw,
            height: ph,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw CaptureError.png }
        ctx.translateBy(x: 0, y: CGFloat(ph))
        ctx.scaleBy(x: scale, y: -scale)
        let dark = NSApp.appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ctx.setFillColor(gray: dark ? 0.17 : 0.93, alpha: 1)
        ctx.fill(CGRect(origin: .zero, size: bounds.size))
        layer.render(in: ctx)
        guard let image = ctx.makeImage() else { throw CaptureError.png }
        return NSBitmapImageRep(cgImage: image)
    }

    /// Window-server snapshot of the on-screen window. Captures NSVisualEffectView
    /// vibrancy that CALayer.render drops. Returns nil if TCC denies Screen Recording.
    private static func windowServerSnapshot(_ window: NSWindow) -> NSBitmapImageRep? {
        let windowID = CGWindowID(window.windowNumber)
        guard windowID != 0 else { return nil }
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreZOrder, .bestResolution]
        ) else {
            VisualQARuntime.trace("CGWindowListCreateImage nil windowID=\(windowID)")
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: image)
        VisualQARuntime.trace("CGWindowListCreateImage \(rep.pixelsWide)x\(rep.pixelsHigh) blankLeft=\(leftColumnIsBlank(rep))")
        if leftColumnIsBlank(rep) { return nil }
        return rep
    }

    /// Restore sidebar pixels from the live RootView hierarchy. Not a second UI:
    /// labels, frames, and selection come from the on-screen NSTableView.
    private static func compositeSidebarFromLiveHierarchy(onto rep: inout NSBitmapImageRep, window: NSWindow) {
        guard let content = window.contentView else { return }
        var table: NSTableView?
        func findTable(_ view: NSView) {
            if table != nil { return }
            if let found = view as? NSTableView {
                table = found
                return
            }
            for sub in view.subviews { findTable(sub) }
        }
        findTable(content)

        guard let copy = writableCopy(rep, pointSize: content.bounds.size) else {
            VisualQARuntime.trace("composite: could not copy bitmap")
            return
        }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let ctx = NSGraphicsContext(bitmapImageRep: copy) else { return }
        NSGraphicsContext.current = ctx

        let dark = NSApp.appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let sidebarWidth = Geometry.sidebarWidth
        (dark ? NSColor(white: 0.18, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: sidebarWidth, height: content.bounds.height)).fill()
        NSColor.separatorColor.setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: sidebarWidth - 0.5, y: 0))
        divider.line(to: NSPoint(x: sidebarWidth - 0.5, y: content.bounds.height))
        divider.lineWidth = 1
        divider.stroke()

        var drawn = 0
        if let table {
            table.layoutSubtreeIfNeeded()
            drawn = drawSidebarCellText(table, into: content, sidebarWidth: sidebarWidth)
            VisualQARuntime.trace("composite: drew \(drawn) live NSTableView labels rows=\(table.numberOfRows)")
        } else {
            VisualQARuntime.trace("composite: no NSTableView in live window")
        }
        limitations.append("sidebar capture: restored \(drawn) live rows (NSVisualEffectView does not flatten under CALayer.render)")
        rep = copy
    }

    @discardableResult
    private static func drawSidebarCellText(_ table: NSTableView, into content: NSView, sidebarWidth: CGFloat) -> Int {
        var drawn = 0
        for row in 0..<table.numberOfRows {
            guard let cell = table.view(atColumn: 0, row: row, makeIfNecessary: true) else { continue }
            let selected = table.selectedRow == row
            let cellFrame = cell.convert(cell.bounds, to: content)
            if selected {
                NSColor.selectedContentBackgroundColor.setFill()
                NSBezierPath(roundedRect: NSRect(x: 8, y: cellFrame.minY, width: sidebarWidth - 16, height: max(cellFrame.height, 1)), xRadius: 6, yRadius: 6).fill()
            }
            var labels: [String] = []
            collectText(cell, into: &labels)
            if labels.isEmpty, let accessibility = cell.accessibilityLabel(), !accessibility.isEmpty {
                labels.append(accessibility)
            }
            guard let text = labels.first, !text.isEmpty else { continue }
            let color: NSColor = selected ? .alternateSelectedControlTextColor : .labelColor
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: color
            ]
            let drawRect = NSRect(x: 28, y: cellFrame.minY + 2, width: sidebarWidth - 40, height: max(cellFrame.height - 4, 12))
            NSAttributedString(string: text, attributes: attrs).draw(with: drawRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
            drawn += 1
        }
        return drawn
    }

    private static func writableCopy(_ rep: NSBitmapImageRep, pointSize: CGSize) -> NSBitmapImageRep? {
        guard let cg = rep.cgImage else { return nil }
        guard let copy = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(rep.pixelsWide, 1),
            pixelsHigh: max(rep.pixelsHigh, 1),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else { return nil }
        copy.size = pointSize
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: copy) {
            NSGraphicsContext.current = ctx
            NSImage(cgImage: cg, size: pointSize).draw(
                in: NSRect(origin: .zero, size: pointSize),
                from: .zero,
                operation: .copy,
                fraction: 1
            )
        }
        NSGraphicsContext.restoreGraphicsState()
        return copy
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
        let record = [
            "file": relative,
            "screen": screen,
            "theme": dark ? "dark" : "light",
            "size": "\(Int(size.width))x\(Int(size.height))",
            "source": source,
            "fixture": fixture ? "true" : "false",
        ]
        if let idx = records.firstIndex(where: { $0["file"] == relative }) {
            records[idx] = record
        } else {
            records.append(record)
        }
    }

    private static func writeManifest() {
        let payload: [String: Any] = [
            "gate4": "NOT PASS",
            "note": "Supplemental screenshots from the packaged DiskPrune.app. Human review still required.",
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
            volumeTotalBytes: 500_000_000_000,
            volumeAvailableBytes: 80_000_000_000,
            classifiedBytes: empty ? 4_000_000_000 : 80_000_000_000,
            unclassifiedScannedBytes: empty ? 0 : 20_000_000_000,
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
