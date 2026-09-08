import AppKit
import Foundation

enum FullDiskAccess {
    /// Heuristic ONLY — never presented as proof that FDA is or is not granted.
    static func probeLikelyGranted() -> Bool {
        let testPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        return FileManager.default.isReadableFile(atPath: testPath)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
