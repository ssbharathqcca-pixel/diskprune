import Foundation
@testable import DiskPrune

/// Deterministic visual-QA data built from production models.
/// Not a second accounting system. Not a production scan. Never executed.
@MainActor
enum VisualQAFixtures {
    static let capturedAt = Date(timeIntervalSince1970: 1_757_350_000)

    static func knowledge() throws -> StorageKnowledge {
        try StorageKnowledge.load()
    }

    static func session(_ configure: (AppSession) -> Void = { _ in }) throws -> AppSession {
        PreferencesStore.scanOnLaunch = false
        let session = AppSession(knowledge: try knowledge())
        session.volumeName = "Macintosh HD"
        configure(session)
        return session
    }

    static func catalogItems(knowledge: StorageKnowledge) -> [StorageItem] {
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

    static func coverage(partial: Bool = false, emptyCandidates: Bool = false) -> StorageCoverage {
        StorageCoverage(
            volumeTotalBytes: 1_000_000_000_000,
            volumeAvailableBytes: 258_000_000_000,
            classifiedBytes: emptyCandidates ? 4_000_000_000 : 86_000_000_000,
            unclassifiedScannedBytes: 2_000_000_000,
            permissionLimitedPaths: partial ? ["/Users/qa/Library/Mail", "/Users/qa/Library/Messages"] : [],
            cleanupCandidateBytes: emptyCandidates ? 0 : 12_400_000_000
        )
    }

    static func snapshots() -> SnapshotSummary {
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

    static func readySession(partial: Bool = false) throws -> AppSession {
        let knowledge = try knowledge()
        return try session { session in
            session.ingestScan(
                items: catalogItems(knowledge: knowledge),
                coverage: coverage(partial: partial),
                snapshots: snapshots()
            )
        }
    }

    static func emptyCandidatesSession() throws -> AppSession {
        let knowledge = try knowledge()
        let protected = item(knowledge, id: "protected-documents", ino: 31, bytes: 80_000_000_000)
        let advanced = item(knowledge, id: "docker-raw", ino: 32, bytes: 4_000_000_000, logical: 20_000_000_000, type: .regularFile)
        return try session { session in
            session.ingestScan(
                items: [protected, advanced],
                coverage: coverage(emptyCandidates: true),
                snapshots: snapshots()
            )
        }
    }

    static func scanningSession() throws -> AppSession {
        try session { session in
            session.phase = .scanning
            session.completedProbes = ["Xcode", "Docker"]
            session.activeProbe = "Package managers"
            session.probeBytes = [
                "Xcode": 38_400_000_000,
                "Docker": 8_100_000_000,
            ]
        }
    }

    static func successReceipt() -> CleanupReceipt {
        let a = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAA1")!
        let b = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAA2")!
        return CleanupReceipt(
            id: UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBB1")!,
            planID: UUID(uuidString: "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCC1")!,
            startedAt: capturedAt,
            finishedAt: capturedAt.addingTimeInterval(4),
            wasCancelled: false,
            estimatedRecoverableBytes: 4_200_000_000,
            successfullyTrashedBytes: 4_180_000_000,
            volumeAvailableBefore: 258_000_000_000,
            volumeAvailableAfter: 258_080_000,
            immediateAvailableDelta: 80_000,
            outcomes: [
                .trashed(itemID: a, path: "/Users/qa/Library/Caches/com.apple.helpd", bytes: 2_100_000_000, resultingTrashURL: nil),
                .trashed(itemID: b, path: "/Users/qa/Library/Developer/Xcode/DerivedData/DemoProject-cafef00d", bytes: 2_080_000_000, resultingTrashURL: nil),
            ],
            trashLocation: "/Users/qa/.Trash",
            appVersion: "1.0.0",
            rulesVersion: (try? knowledge().rulesVersion) ?? "unknown"
        )
    }

    static func failureReceipt() -> CleanupReceipt {
        let a = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAA3")!
        let b = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAA4")!
        return CleanupReceipt(
            id: UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBB2")!,
            planID: UUID(uuidString: "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCC2")!,
            startedAt: capturedAt,
            finishedAt: capturedAt.addingTimeInterval(2),
            wasCancelled: false,
            estimatedRecoverableBytes: 1_800_000_000,
            successfullyTrashedBytes: 0,
            volumeAvailableBefore: 258_000_000_000,
            volumeAvailableAfter: 258_000_000_000,
            immediateAvailableDelta: 0,
            outcomes: [
                .failed(itemID: a, path: "/Users/qa/Library/Logs/locked.log", bytes: 800_000_000, reason: .permissionDenied),
                .skipped(itemID: b, path: "/Users/qa/Library/Caches/gone", bytes: 1_000_000_000, reason: .vanished),
            ],
            trashLocation: "/Users/qa/.Trash",
            appVersion: "1.0.0",
            rulesVersion: (try? knowledge().rulesVersion) ?? "unknown"
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
            newestModification: capturedAt,
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
}
