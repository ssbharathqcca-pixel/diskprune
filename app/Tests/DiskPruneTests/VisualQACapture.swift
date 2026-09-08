import AppKit
import CoreGraphics
import Foundation
import SwiftUI
@testable import DiskPrune

struct VisualQARecord: Codable {
    let file: String
    let screen: String
    let theme: String
    let size: String
    let source: String
    let fixture: Bool
}

enum VisualQACapture {
    static var records: [VisualQARecord] = []
    static var limitations: [String] = []

    static var outputRoot: URL {
        if let path = ProcessInfo.processInfo.environment["DISKPRUNE_VISUAL_QA_OUT"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("visual-qa-shots", isDirectory: true)
    }

    static func bootstrap() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.appearance = NSAppearance(named: .aqua)
        PreferencesStore.scanOnLaunch = false
        try? FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
    }

    static func appearance(dark: Bool) -> NSAppearance {
        NSAppearance(named: dark ? .darkAqua : .aqua)!
    }

    static func captureRoot(
        _ session: AppSession,
        screen: String,
        dark: Bool,
        size: CGSize
    ) throws {
        try captureRoot(session, screen: screen, dark: dark, size: size, fixture: screen != "01-first-launch")
    }

    static func captureRoot(
        _ session: AppSession,
        screen: String,
        dark: Bool,
        size: CGSize,
        fixture: Bool
    ) throws {
        let scheme: ColorScheme = dark ? .dark : .light
        let view = RootView(session: session)
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, scheme)
            .preferredColorScheme(scheme)
            .transaction { $0.animation = nil }
        try render(
            view,
            screen: screen,
            dark: dark,
            size: size,
            folder: "\(dark ? "dark" : "light")/\(Int(size.width))x\(Int(size.height))",
            source: "production-RootView",
            fixture: fixture
        )
    }

    static func captureStandalone<V: View>(
        _ view: V,
        screen: String,
        dark: Bool,
        size: CGSize
    ) throws {
        let scheme: ColorScheme = dark ? .dark : .light
        let wrapped = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, scheme)
            .preferredColorScheme(scheme)
            .transaction { $0.animation = nil }
        try render(
            wrapped,
            screen: screen,
            dark: dark,
            size: size,
            folder: "sheets/\(dark ? "dark" : "light")",
            source: "production-view",
            fixture: true
        )
    }

    static func render<V: View>(
        _ view: V,
        screen: String,
        dark: Bool,
        size: CGSize,
        folder: String,
        source: String,
        fixture: Bool
    ) throws {
        let appearance = appearance(dark: dark)
        NSApp.appearance = appearance

        let hosting = NSHostingView(rootView: view)
        hosting.appearance = appearance
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DiskPrune"
        window.appearance = appearance
        window.contentView = hosting
        window.setContentSize(size)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: 40, y: 40))
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        window.displayIfNeeded()
        spin(0.45)

        let relative = "\(folder)/\(screen).png"
        let url = outputRoot.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        if let image = windowImage(window), !isBlank(image) {
            try writePNG(image, to: url)
        } else if let image = viewImage(hosting) {
            try writePNG(image, to: url)
        } else {
            throw CaptureError.blank(relative)
        }

        records.append(VisualQARecord(
            file: relative,
            screen: screen,
            theme: dark ? "dark" : "light",
            size: "\(Int(size.width))x\(Int(size.height))",
            source: source,
            fixture: fixture
        ))
        window.orderOut(nil)
        window.close()
    }

    static func captureRealApp(at appURL: URL) async throws {
        for running in NSRunningApplication.runningApplications(withBundleIdentifier: "com.diskprune.app") {
            running.terminate()
        }
        spin(0.4)

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.createsNewApplicationInstance = true
        let launched = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        spin(3.0)

        let pid = launched.processIdentifier
        let relative = "real-app/first-launch.png"
        let url = outputRoot.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        guard let image = imageForPID(pid) else {
            launched.terminate()
            limitations.append("Real DiskPrune.app launched (pid \(pid)) but CGWindowListCreateImage returned nil — likely Screen Recording TCC on the runner. Hosted RootView shots remain the reviewable evidence.")
            return
        }
        try writePNG(image, to: url)
        records.append(VisualQARecord(
            file: relative,
            screen: "01-first-launch",
            theme: "system",
            size: "native",
            source: "packaged-DiskPrune.app",
            fixture: false
        ))
        launched.terminate()
        spin(0.4)
    }


    static func writeManifest() throws {
        struct Manifest: Codable {
            let gate4: String
            let note: String
            let shots: [VisualQARecord]
            let limitations: [String]
        }
        let body = Manifest(
            gate4: "NOT PASS",
            note: "Supplemental screenshot evidence from production SwiftUI views hosted in a real AppKit window on macos-latest. Human visual review is still required. Gate 4 is not passed by this workflow.",
            shots: records,
            limitations: limitations
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(body)
        try data.write(to: outputRoot.appendingPathComponent("manifest.json"))

        var index = """
        DiskPrune Visual QA screenshots
        Gate 4: NOT PASS (human review required)

        """
        for record in records {
            index += "- \(record.file)  [\(record.theme) \(record.size)]  source=\(record.source)  fixture=\(record.fixture)\n"
        }
        if !limitations.isEmpty {
            index += "\nLimitations:\n"
            for line in limitations {
                index += "- \(line)\n"
            }
        }
        try index.write(to: outputRoot.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
    }

    private static func windowImage(_ window: NSWindow) -> NSBitmapImageRep? {
        let windowID = CGWindowID(window.windowNumber)
        guard windowID != 0,
              let cg = CGWindowListCreateImage(
                CGRect.null,
                .optionIncludingWindow,
                windowID,
                [.boundsIgnoreFraming, .bestResolution]
              )
        else { return nil }
        return NSBitmapImageRep(cgImage: cg)
    }

    private static func viewImage(_ view: NSView) -> NSBitmapImageRep? {
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        if isBlank(rep) { return nil }
        return rep
    }

    private static func imageForPID(_ pid: pid_t) -> NSBitmapImageRep? {
        guard let info = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for window in info {
            let owner = window[kCGWindowOwnerPID as String] as? pid_t
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            guard owner == pid, layer == 0 else { continue }
            guard let number = window[kCGWindowNumber as String] as? CGWindowID else { continue }
            guard let cg = CGWindowListCreateImage(
                CGRect.null,
                .optionIncludingWindow,
                number,
                [.boundsIgnoreFraming, .bestResolution]
            ) else { continue }
            return NSBitmapImageRep(cgImage: cg)
        }
        return nil
    }

    private static func isBlank(_ rep: NSBitmapImageRep) -> Bool {
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        guard width > 8, height > 8, let data = rep.bitmapData else { return true }
        var opaque = 0
        let bpp = max(rep.bitsPerPixel / 8, 1)
        let stride = rep.bytesPerRow
        for y in stride(from: 0, to: height, by: 16) {
            for x in stride(from: 0, to: width, by: 16) {
                let pixel = data + y * stride + x * bpp
                if bpp >= 4 {
                    if pixel[3] > 8 { opaque += 1 }
                } else if pixel[0] + pixel[min(1, bpp - 1)] > 8 {
                    opaque += 1
                }
            }
        }
        return opaque < 4
    }

    private static func writePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw CaptureError.png
        }
        try png.write(to: url)
        if png.count < 2_000 { throw CaptureError.blank(url.lastPathComponent) }
    }

    private static func spin(_ seconds: Double) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    enum CaptureError: Error, CustomStringConvertible {
        case blank(String)
        case png
        case launchFailed
        var description: String {
            switch self {
            case .blank(let name): return "blank screenshot: \(name)"
            case .png: return "could not encode PNG"
            case .launchFailed: return "failed to launch DiskPrune.app"
            }
        }
    }
}
