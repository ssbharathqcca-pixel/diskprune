import Foundation

struct DockerProbe: Probe {
    let name = "Docker"

    private let candidates = [
        "~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw",
        "~/Library/Containers/com.docker.docker/Data/vms/0/Docker.raw",
        "~/.docker/desktop/vms/0/data/Docker.raw",
        "~/Library/Containers/com.docker.docker/Data",
        "~/.colima",
        "~/.orbstack",
    ]

    func discover(knowledge: StorageKnowledge, globalSeen: SeenFileIDs) async -> [StorageItem] {
        var items: [StorageItem] = []
        var found = false
        for raw in candidates {
            let path = ProbeSupport.expand(raw)
            guard ProbeSupport.exists(path) else { continue }
            found = true
            let url = URL(fileURLWithPath: path)
            if let item = await ProbeSupport.item(at: url, knowledge: knowledge, globalSeen: globalSeen) {
                items.append(item)
            }
        }
        _ = found
        return items
    }
}
