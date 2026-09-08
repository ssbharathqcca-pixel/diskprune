import Foundation

struct CacheProbe: Probe {
    let name = "Caches"

    func discover(knowledge: StorageKnowledge, globalSeen: SeenFileIDs) async -> [StorageItem] {
        let root = URL(fileURLWithPath: ProbeSupport.expand("~/Library/Caches"))
        guard ProbeSupport.exists(root.path) else { return [] }

        let children: [URL]
        do {
            children = try FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            if let item = await ProbeSupport.item(at: root, knowledge: knowledge, globalSeen: globalSeen) {
                return [item]
            }
            return []
        }

        var items: [StorageItem] = []
        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let (safety, _, _) = knowledge.classify(path: child.path)
            if safety == .protected { continue }
            if let item = await ProbeSupport.item(
                at: child,
                knowledge: knowledge,
                globalSeen: globalSeen,
                cleanupRoot: root
            ) {
                items.append(item)
            }
        }
        return items
    }
}
