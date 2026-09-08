import Foundation

struct PlannedItem: Sendable {
    let itemID: UUID
    let url: URL
    let fileID: FileID
    let objectType: ObjectType
    let cleanupRoot: URL
    let estimatedBytes: Int64
    let displayName: String
    let safety: SafetyLevel

    /// The ONLY way to construct a PlannedItem. Failable by design.
    init?(item: StorageItem, userSelected: Bool) {
        guard userSelected else { return nil }
        guard item.safety.isPlannable else { return nil }
        guard item.isCleanupCandidate else { return nil }
        guard item.objectType != .symlink else { return nil }
        guard !PathValidator.hasAppComponent(item.url.path) else { return nil }
        guard PathValidator.isStrictDescendant(item.url, of: item.cleanupRoot) else { return nil }
        guard !PathValidator.isDenied(item.url.path) else { return nil }
        let path = item.url.standardized.path
        guard path != "/",
              path != NSHomeDirectory(),
              PathValidator.pathDepth(path) >= 3
        else { return nil }

        self.itemID = item.id
        self.url = item.url
        self.fileID = item.fileID
        self.objectType = item.objectType
        self.cleanupRoot = item.cleanupRoot
        self.estimatedBytes = item.onDiskBytes
        self.displayName = item.displayName
        self.safety = item.safety
    }
}
