import Foundation

struct CleanupPlan: Sendable {
    let id: UUID
    let createdAt: Date
    let items: [PlannedItem]

    var estimatedRecoverableBytes: Int64 {
        items.reduce(0) { $0 + $1.estimatedBytes }
    }

    var itemCount: Int { items.count }

    init?(items: [PlannedItem]) {
        guard !items.isEmpty else { return nil }
        let paths = items.map { $0.url.standardized.path }
        for i in 0..<paths.count {
            for j in 0..<paths.count where i != j {
                let a = paths[i]
                let b = paths[j]
                if a == b || a.hasPrefix(b + "/") || b.hasPrefix(a + "/") {
                    return nil
                }
            }
        }
        self.id = UUID()
        self.createdAt = Date()
        self.items = items.sorted { PathValidator.pathDepth($0.url.path) > PathValidator.pathDepth($1.url.path) }
    }
}
