import Foundation

struct LogProbe: Probe {
    let name = "Logs"

    func discover(knowledge: StorageKnowledge, globalSeen: SeenFileIDs) async -> [StorageItem] {
        var items: [StorageItem] = []
        let userLogs = URL(fileURLWithPath: ProbeSupport.expand("~/Library/Logs"))
        if ProbeSupport.exists(userLogs.path),
           let item = await ProbeSupport.item(at: userLogs, knowledge: knowledge, globalSeen: globalSeen) {
            items.append(item)
        }
        let systemLogs = URL(fileURLWithPath: "/Library/Logs")
        if ProbeSupport.exists(systemLogs.path),
           let item = await ProbeSupport.item(at: systemLogs, knowledge: knowledge, globalSeen: globalSeen) {
            items.append(item)
        }
        return items
    }
}
