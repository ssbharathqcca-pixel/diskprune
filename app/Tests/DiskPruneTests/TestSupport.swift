import Darwin
import Foundation
@testable import DiskPrune

enum TestSupport {
    static func uniqueTemp() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskprune-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func writeRandomFile(at url: URL, size: Int) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = Data(count: size)
        data.withUnsafeMutableBytes { buf in
            guard let base = buf.baseAddress else { return }
            arc4random_buf(base, buf.count)
        }
        try data.write(to: url)
    }

    static func makeItem(
        url: URL,
        fileID: FileID = FileID(dev: 1, ino: 1),
        objectType: ObjectType = .directory,
        displayName: String = "test",
        onDiskBytes: Int64 = 100,
        category: DiskPrune.Category = .applicationCache,
        safety: SafetyLevel = .safe,
        knowledgeID: String? = "user-caches",
        cleanupRoot: URL? = nil,
        scanState: ScanState = .complete
    ) -> StorageItem {
        StorageItem(
            url: url,
            fileID: fileID,
            objectType: objectType,
            displayName: displayName,
            onDiskBytes: onDiskBytes,
            logicalBytes: onDiskBytes,
            fileCount: 1,
            newestModification: Date(),
            category: category,
            safety: safety,
            knowledgeID: knowledgeID,
            explanation: "Test item used by unit tests for planning and cleanup.",
            consequence: "Test consequence text that is long enough to be descriptive.",
            regenerable: true,
            cleanupRoot: cleanupRoot ?? url,
            scanState: scanState
        )
    }
}
