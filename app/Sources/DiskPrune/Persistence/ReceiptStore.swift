import Foundation

enum ReceiptStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("com.diskprune.app/Receipts", isDirectory: true)
    }

    static func save(_ receipt: CleanupReceipt) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: receipt.startedAt)
        let prefix = receipt.id.uuidString.lowercased().prefix(8)
        let url = directory.appendingPathComponent("receipt-\(stamp)-\(prefix).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(receipt)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func list() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    }

    static func load(_ url: URL) throws -> CleanupReceipt {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CleanupReceipt.self, from: data)
    }
}
