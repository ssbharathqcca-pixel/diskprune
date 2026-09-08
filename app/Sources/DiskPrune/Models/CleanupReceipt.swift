import Foundation

struct CleanupReceipt: Sendable, Codable {
    let id: UUID
    let planID: UUID
    let startedAt: Date
    let finishedAt: Date
    let wasCancelled: Bool

    let estimatedRecoverableBytes: Int64
    let successfullyTrashedBytes: Int64
    let volumeAvailableBefore: Int64?
    let volumeAvailableAfter: Int64?
    let immediateAvailableDelta: Int64?

    let outcomes: [ItemOutcome]
    let trashLocation: String?
    let appVersion: String
    let rulesVersion: String
}

enum ItemOutcome: Sendable, Codable, Equatable {
    case trashed(itemID: UUID, path: String, bytes: Int64, resultingTrashURL: String?)
    case failed(itemID: UUID, path: String, bytes: Int64, reason: FailureReason)
    case skipped(itemID: UUID, path: String, bytes: Int64, reason: SkipReason)
}

enum FailureReason: String, Codable, Equatable {
    case permissionDenied
    case trashUnavailable
    case crossVolume
    case fileBusy
    case readOnlyVolume
    case unknown
}

enum SkipReason: String, Codable, Equatable {
    case vanished
    case becameSymlink
    case typeChanged
    case identityChanged
    case escapedCleanupRoot
    case appBundleAncestor
    case denyListed
    case cancelled
}
