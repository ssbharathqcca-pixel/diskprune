import Foundation

struct StorageCoverage: Sendable, Codable {
    let volumeTotalBytes: Int64
    let volumeAvailableBytes: Int64
    let volumeUsedBytes: Int64
    let classifiedBytes: Int64
    let unclassifiedScannedBytes: Int64
    let examinedBytes: Int64
    let notExaminedBytes: Int64
    let permissionLimitedPaths: [String]
    let permissionLimitedBytes: Int64?
    let cleanupCandidateBytes: Int64

    init(
        volumeTotalBytes: Int64,
        volumeAvailableBytes: Int64,
        classifiedBytes: Int64,
        unclassifiedScannedBytes: Int64,
        permissionLimitedPaths: [String],
        cleanupCandidateBytes: Int64
    ) {
        self.volumeTotalBytes = volumeTotalBytes
        self.volumeAvailableBytes = volumeAvailableBytes
        self.volumeUsedBytes = max(0, volumeTotalBytes - volumeAvailableBytes)
        self.classifiedBytes = classifiedBytes
        self.unclassifiedScannedBytes = unclassifiedScannedBytes
        let examined = classifiedBytes + unclassifiedScannedBytes
        self.examinedBytes = examined
        self.notExaminedBytes = max(0, self.volumeUsedBytes - examined)
        self.permissionLimitedPaths = permissionLimitedPaths
        self.permissionLimitedBytes = nil
        self.cleanupCandidateBytes = cleanupCandidateBytes
    }
}
