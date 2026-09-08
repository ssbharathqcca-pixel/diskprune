import Foundation

struct VolumeSpace: Sendable {
    let total: Int64
    let available: Int64
    let measuredAt: Date
}

enum SpaceVerifier {
    static func measure(volumeContaining url: URL) -> VolumeSpace? {
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey,
            ])
            guard let total = values.volumeTotalCapacity else { return nil }
            // ImportantUsage is Int64?; AvailableCapacity is Int?. Do not mix with ??.
            let available: Int64
            if let important = values.volumeAvailableCapacityForImportantUsage {
                available = important
            } else if let fallback = values.volumeAvailableCapacity {
                available = Int64(fallback)
            } else {
                return nil
            }
            return VolumeSpace(total: Int64(total), available: available, measuredAt: Date())
        } catch {
            return nil
        }
    }
}
