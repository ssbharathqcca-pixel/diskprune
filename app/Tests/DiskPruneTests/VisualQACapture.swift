import AppKit
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

/// Renders production SwiftUI views off-screen.
/// Does not use CGWindowListCreateImage / ScreenCaptureKit — those abort on
/// GitHub-hosted runners without Screen Recording TCC (signal 5).
@MainActor
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
        app.setActivationPolicy(.accessory)
        app.appearance = NSAppearance(named: .aqua)
        PreferencesStore.scanOnLaunch = false
        try? FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        limitations.append("Window chrome is NSHostingView content, not CGWindowList of a user session. Packaged-app PNG is attempted by scripts/visual-qa.sh.")
    }

    static func appearance(dark: Bool) -> NSAppearance {
        NSAppearance(named: dark ? .darkAqua : .aqua) ?? NSAppearance(named: .aqua)!
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

        let relative = "\(folder)/\(screen).png"
        let url = outputRoot.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        if let image = imageRenderer(view, size: size, appearance: appearance) {
            try writePNG(image, to: url)
        } else if let image = hostingBitmap(view, size: size, appearance: appearance) {
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
            note: "Supplemental screenshot evidence from production SwiftUI views on macos-latest. Human visual review is still required. Gate 4 is not passed by this workflow.",
            shots: records,
            limitations: limitations
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(body).write(to: outputRoot.appendingPathComponent("manifest.json"))

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

    private static func imageRenderer<V: View>(_ view: V, size: CGSize, appearance: NSAppearance) -> NSBitmapImageRep? {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 2
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              !isBlank(rep)
        else { return nil }
        _ = appearance
        return rep
    }

    private static func hostingBitmap<V: View>(_ view: V, size: CGSize, appearance: NSAppearance) -> NSBitmapImageRep? {
        let hosting = NSHostingView(rootView: view)
        hosting.appearance = appearance
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.wantsLayer = true
        hosting.layer?.contentsScale = 2
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        spin(0.2)
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if isBlank(rep) { return nil }
        return rep
    }

    private static func isBlank(_ rep: NSBitmapImageRep) -> Bool {
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        guard width > 8, height > 8, let data = rep.bitmapData else { return true }
        var opaque = 0
        let bpp = max(rep.bitsPerPixel / 8, 1)
        let bytesPerRow = rep.bytesPerRow
        for y in Swift.stride(from: 0, to: height, by: 16) {
            for x in Swift.stride(from: 0, to: width, by: 16) {
                let pixel = data + y * bytesPerRow + x * bpp
                if bpp >= 4 {
                    if pixel[3] > 8 { opaque += 1 }
                } else if pixel[0] > 8 {
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
        var description: String {
            switch self {
            case .blank(let name): return "blank screenshot: \(name)"
            case .png: return "could not encode PNG"
            }
        }
    }
}
