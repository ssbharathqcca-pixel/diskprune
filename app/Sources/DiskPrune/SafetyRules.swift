import Foundation

struct SafetyRules {
    static func tier1Paths() -> [String] {
        let home = NSHomeDirectory()
        return [
            "\(home)/Library/Caches",
            "\(home)/Library/Logs",
            "/Library/Logs",
            "\(home)/Library/Developer/Xcode/DerivedData",
            "\(home)/.npm/_cacache",
            "\(home)/.cargo/registry/cache",
            "\(home)/.gradle/caches"
        ]
    }
    
    static func tier2Paths() -> [String] {
        let home = NSHomeDirectory()
        return [
            "\(home)/Library/Containers",
            "\(home)/Library/Application Support",
            "\(home)/.docker/desktop"
        ]
    }
}
