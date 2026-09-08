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
            let available = values.volumeAvailableCapacityForImportantUsage
                ?? values.volumeAvailableCapacity
            guard let available else { return nil }
            return VolumeSpace(total: Int64(total), available: Int64(available), measuredAt: Date())
        } catch {
            return nil
        }
    }
}
