import Foundation
import AppKit

actor ScannerActor {
    let fileManager = FileManager.default

    func scanSafeTier() async -> [URL] {
        var foundURLs: [URL] = []
        let safePaths = SafetyRules.tier1Paths()

        for path in safePaths {
            let url = URL(fileURLWithPath: path)
            if let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey]
            ) {
                for case let fileURL as URL in enumerator {
                    foundURLs.append(fileURL)
                }
            }
        }
        return foundURLs
    }

    func trash(urls: [URL]) async throws {
        for url in urls {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        }
    }

    func checkFullDiskAccess() -> Bool {
        let testPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        return fileManager.isReadableFile(atPath: testPath)
    }

    func requestFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
