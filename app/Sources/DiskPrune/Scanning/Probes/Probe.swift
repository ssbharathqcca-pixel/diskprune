import Foundation

protocol Probe: Sendable {
    var name: String { get }
    func discover(knowledge: StorageKnowledge, globalSeen: SeenFileIDs) async -> [StorageItem]
}

enum ProbeSupport {
    static func expand(_ path: String) -> String {
        if path == "~" { return NSHomeDirectory() }
        if path.hasPrefix("~/") {
            return NSHomeDirectory() + String(path.dropFirst(1))
        }
        return path
    }

    static func exists(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
    }

    static func item(
        at url: URL,
        knowledge: StorageKnowledge,
        globalSeen: SeenFileIDs,
        displayName: String? = nil,
        cleanupRoot: URL? = nil
    ) async -> StorageItem? {
        let size = await DirectorySizer.measure(root: url, globalSeen: globalSeen)
        guard size.scanState != .denied || size.onDiskBytes > 0 || !size.deniedPaths.isEmpty else {
            switch FileIdentity.lstat(url.path) {
            case .failure(.notFound), .failure(.tooManyLinks), .failure(.other):
                return nil
            default:
                break
            }
            return nil
        }
        guard case .success(let st) = FileIdentity.lstat(url.path) else {
            if size.scanState == .denied {
                return nil
            }
            return nil
        }
        if st.objectType == .symlink { return nil }

        let (safety, category, rule) = knowledge.classify(path: url.path)
        let name = displayName ?? rule?.displayName ?? url.lastPathComponent
        let root = cleanupRoot ?? url
        return StorageItem(
            url: url,
            fileID: st.fileID,
            objectType: st.objectType,
            displayName: name,
            onDiskBytes: size.onDiskBytes,
            logicalBytes: size.logicalBytes,
            fileCount: size.fileCount,
            newestModification: size.newestModification,
            category: category,
            safety: safety,
            knowledgeID: rule?.id,
            explanation: rule?.explanation ?? "DiskPrune doesn't have a rule for this location.",
            consequence: rule?.consequence ?? "Unclassified locations are never pre-selected for cleanup.",
            regenerable: rule?.regenerable ?? false,
            cleanupRoot: root,
            scanState: size.scanState,
            sizeApproximate: size.sizeApproximate
        )
    }
}
