import Foundation

struct PackageManagerProbe: Probe {
    let name = "Package managers"

    func discover(knowledge: StorageKnowledge, globalSeen: SeenFileIDs) async -> [StorageItem] {
        let locations: [(env: String?, paths: [String])] = [
            ("npm_config_cache", ["~/.npm/_cacache"]),
            ("PNPM_HOME", ["~/Library/pnpm/store", "~/.pnpm-store"]),
            (nil, ["~/Library/Caches/Yarn", "~/.yarn/berry/cache"]),
            ("CARGO_HOME", ["~/.cargo/registry/cache"]),
            ("GRADLE_USER_HOME", ["~/.gradle/caches"]),
            (nil, ["~/.m2/repository"]),
            (nil, ["~/Library/Caches/CocoaPods"]),
            (nil, ["~/Library/Caches/org.swift.swiftpm"]),
            ("HOMEBREW_CACHE", ["~/Library/Caches/Homebrew"]),
        ]

        var items: [StorageItem] = []
        for loc in locations {
            var paths = loc.paths
            if let env = loc.env, let value = ProcessInfo.processInfo.environment[env], !value.isEmpty {
                if env == "npm_config_cache" {
                    paths = [value]
                } else if env == "PNPM_HOME" {
                    paths = [value.hasSuffix("/store") ? value : value + "/store"]
                } else if env == "CARGO_HOME" {
                    paths = [value + "/registry/cache"]
                } else if env == "GRADLE_USER_HOME" {
                    paths = [value + "/caches"]
                } else {
                    paths = [value]
                }
            }
            for p in paths {
                let expanded = ProbeSupport.expand(p)
                guard ProbeSupport.exists(expanded) else { continue }
                if let item = await ProbeSupport.item(
                    at: URL(fileURLWithPath: expanded),
                    knowledge: knowledge,
                    globalSeen: globalSeen
                ) {
                    items.append(item)
                }
            }
        }
        return items
    }
}
