import Foundation

enum PreferencesStore {
    private static let suite = UserDefaults.standard

    static func setLastScanAt(_ date: Date) {
        suite.set(date.timeIntervalSince1970, forKey: "lastScanAt")
    }

    static func lastScanAt() -> Date? {
        let value = suite.double(forKey: "lastScanAt")
        guard value > 0 else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    static var scanOnLaunch: Bool {
        get { suite.bool(forKey: "scanOnLaunch") }
        set { suite.set(newValue, forKey: "scanOnLaunch") }
    }

    static func resetWarnings() {
        suite.removeObject(forKey: "warningsResetAt")
        suite.set(Date().timeIntervalSince1970, forKey: "warningsResetAt")
    }
}
