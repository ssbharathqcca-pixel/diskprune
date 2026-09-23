import Foundation

struct StorageRulesFile: Sendable, Codable {
    let schemaVersion: Int
    let rulesVersion: String
    let generated: Bool?
    let source: String?
    let rules: [StorageRule]
}

enum StorageKnowledgeError: Error {
    case missingResource
    case malformedJSON(Error)
}

final class StorageKnowledge: Sendable {
    let rulesVersion: String
    let publishedRuleIDs: [String]
    private let rules: [StorageRule]

    init(file: StorageRulesFile) {
        self.rulesVersion = file.rulesVersion
        self.rules = file.rules
        self.publishedRuleIDs = file.rules.filter(\.publish).map(\.id)
    }

    static func load() throws -> StorageKnowledge {
        // Bundle.module uses a SPM-generated accessor that calls fatalError when the
        // resource bundle can't be found — bypassing the ?? fallback below. In a
        // notarized .app, build-universal.sh copies storage-rules.json directly to
        // Contents/Resources, so Bundle.main finds it without the intermediate bundle.
        // For development (swift run / Xcode), we manually search for the SPM bundle
        // alongside the executable rather than calling Bundle.module and crashing.
        let url = Bundle.main.url(forResource: "storage-rules", withExtension: "json")
            ?? Self.storageRulesURLFromSPMBundle()
        guard let url else { throw StorageKnowledgeError.missingResource }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw StorageKnowledgeError.missingResource
        }
        return try load(from: data)
    }

    private static func storageRulesURLFromSPMBundle() -> URL? {
        // Fallback for development: look for the SPM-generated resource bundle.
        // The generated resource_bundle_accessor checks Bundle.main.bundleURL (root
        // of .app, or executable dir in CLI mode) and a hard-coded build-time path —
        // we replicate that search here without calling fatalError.
        let candidates = [Bundle.main.resourceURL, Bundle.main.bundleURL].compactMap { $0 }
        for base in candidates {
            let bundlePath = base.appendingPathComponent("DiskPrune_DiskPrune.bundle")
            if let bundle = Bundle(url: bundlePath),
               let url = bundle.url(forResource: "storage-rules", withExtension: "json") {
                return url
            }
        }
        return nil
    }

    static func load(from data: Data) throws -> StorageKnowledge {
        let decoder = JSONDecoder()
        let file: StorageRulesFile
        do {
            file = try decoder.decode(StorageRulesFile.self, from: data)
        } catch {
            throw StorageKnowledgeError.malformedJSON(error)
        }
        if file.schemaVersion != 1 {
            throw StorageKnowledgeError.malformedJSON(
                NSError(domain: "DiskPrune", code: 1, userInfo: [NSLocalizedDescriptionKey: "schemaVersion"])
            )
        }
        return StorageKnowledge(file: file)
    }

    func expandedPaths(for rule: StorageRule) -> [String] {
        var paths = rule.paths
        if let env = rule.envOverride, let value = ProcessInfo.processInfo.environment[env], !value.isEmpty {
            paths[0] = value
        }
        return paths.map { expandHome($0) }
    }

    func rule(forPath path: String) -> StorageRule? {
        let standardized = (expandHome(path) as NSString).standardizingPath
        var bestProtected: (StorageRule, Int)?
        var bestOther: (StorageRule, Int)?

        for rule in rules {
            for prefix in expandedPaths(for: rule) {
                let p = (prefix as NSString).standardizingPath
                guard standardized == p || standardized.hasPrefix(p + "/") else { continue }
                let len = p.count
                if rule.safety == .protected {
                    if bestProtected == nil || len > bestProtected!.1 {
                        bestProtected = (rule, len)
                    }
                } else {
                    if bestOther == nil || len > bestOther!.1 {
                        bestOther = (rule, len)
                    }
                }
            }
        }

        switch (bestProtected, bestOther) {
        case let (prot?, other?):
            if prot.1 >= other.1 { return prot.0 }
            return other.0
        case let (prot?, nil):
            return prot.0
        case let (nil, other?):
            return other.0
        case (nil, nil):
            return nil
        }
    }

    func rule(id: String) -> StorageRule? {
        rules.first { $0.id == id }
    }

    func classify(path: String) -> (SafetyLevel, Category, StorageRule?) {
        if let rule = rule(forPath: path) {
            return (rule.safety, rule.category, rule)
        }
        return (.review, .unknown, nil)
    }

    var allRules: [StorageRule] { rules }

    private func expandHome(_ path: String) -> String {
        if path == "~" { return NSHomeDirectory() }
        if path.hasPrefix("~/") {
            return NSHomeDirectory() + String(path.dropFirst(1))
        }
        return path
    }
}
