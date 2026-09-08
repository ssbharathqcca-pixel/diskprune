import Foundation

struct StorageItem: Identifiable, Sendable, Codable {
    let id: UUID
    let url: URL
    let fileID: FileID
    let objectType: ObjectType
    let displayName: String
    let onDiskBytes: Int64
    let logicalBytes: Int64
    let fileCount: Int
    let newestModification: Date?
    let category: Category
    let safety: SafetyLevel
    let knowledgeID: String?
    let explanation: String
    let consequence: String
    let regenerable: Bool
    let cleanupRoot: URL
    let scanState: ScanState
    let isCleanupCandidate: Bool
    let sizeApproximate: Bool

    init(
        id: UUID = UUID(),
        url: URL,
        fileID: FileID,
        objectType: ObjectType,
        displayName: String,
        onDiskBytes: Int64,
        logicalBytes: Int64,
        fileCount: Int,
        newestModification: Date?,
        category: Category,
        safety: SafetyLevel,
        knowledgeID: String?,
        explanation: String,
        consequence: String,
        regenerable: Bool,
        cleanupRoot: URL,
        scanState: ScanState,
        sizeApproximate: Bool = false
    ) {
        self.id = id
        self.url = url.standardizedFileURL
        self.fileID = fileID
        self.objectType = objectType
        self.displayName = displayName
        self.onDiskBytes = onDiskBytes
        self.logicalBytes = logicalBytes
        self.fileCount = fileCount
        self.newestModification = newestModification
        self.category = category
        self.safety = safety
        self.knowledgeID = knowledgeID
        self.explanation = explanation
        self.consequence = consequence
        self.regenerable = regenerable
        self.cleanupRoot = cleanupRoot.standardizedFileURL
        self.scanState = scanState
        self.sizeApproximate = sizeApproximate
        self.isCleanupCandidate =
            safety.isPlannable
            && knowledgeID != nil
            && objectType != .symlink
    }
}
